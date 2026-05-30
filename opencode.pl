#!/usr/bin/perl

use strict; use warnings;

# scope this, the $bd and $ln will be garbage collected, but $0 set. Doesn't
# matter alot, as we'll exec another process over it at the end
{
    my $bd = $ENV{BDIR}    // "session";
    $bd =~ s/^.*\///g;
    $bd =~ s/[^a-zA-Z0-9_-]/_/g;
    my $ln = $ENV{LOGNAME} // "node";
    $ln =~ s/[^a-zA-Z0-9_-]/_/g;
    $0 = "opencode:$ln:$bd";
}

use File::Path qw(make_path);
use File::Find;
use File::stat;


sub copy_file {
    my ($src, $dst) = @_;
    if (open(my $in, "<", $src) and open(my $out, ">", $dst)) {
        local $/; my $data = <$in>; print $out $data; close($in); close($out);
        return 1;
    }
    0;
}

sub set_mtime {
    my ($file, $mtime) = @_;
    utime($mtime, $mtime, $file);
}

sub copy_tree {
    my ($src, $dst_dir) = @_;
    find({
        no_chdir => 1,
        follow_skip => 2,
        wanted => sub {
            my $rel; { local $File::Find::name = $_; ($rel = $_) =~ s{^\Q${src}/?\E}{}o; }
            my $dest = "$dst_dir/$rel";

            if (-l $_) {
                unlink($dest) if -e $dest;
                symlink(readlink($_), $dest);
            } elsif (-d $_) {
                make_path($dest) unless -d $dest;
                my $st = lstat($_);
                chmod($st->mode, $dest) if defined($st);
                set_mtime($dest, $st->mtime) if defined($st);
                chown(1000, 1000, $dest) if -e $dest;
            } elsif (-f $_) {
                copy_file($_, $dest);
                my $st = stat($_);
                chmod($st->mode & 07777, $dest) if defined($st);
                set_mtime($dest, $st->mtime) if defined($st);
                chown(1000, 1000, $dest) if -e $dest;
            }
        },
    }, $src);
}


# Clear error flag before privilege operations
$! = 0;

# Drop group privileges: set real GID to 1000 (node group)
$( = 1000;
die "Error setting RGID to 1000: $!"
    if $!;
$! = 0;

# Set effective GID to 1000 and preserve docker group (983) in supplementary groups
# Format: "primary_gid supplementary_gid1 supplementary_gid2 ..."
$) = "1000 983";
die "Error setting EGID to 1000 with docker group 983: $!"
    if $!;

# Set umask to 0022 (owner=rwx, group=rx, other=rx for new dirs; rw-r--r-- for files)
umask 0022;
die "Error setting umask 0022: $!"
    if $!;

# if containerd sock, group change it
if(-S "/tmp/containerd.sock"){
    chown(1000, 1000, "/tmp/containerd.sock")
        or die "Error changing ownership of /tmp/containerd.sock to 1000: $!";
}

# make /workspace/.bash_history
my $history_path = "/workspace/.bash_history";
if(!-f $history_path){
    open(my $fh, ">", $history_path)
        or die "Failed to create $history_path: $!";
    close($fh);
    chown(1000, 1000, $history_path)
        or die "Error changing ownership of $history_path to 1000: $!";
}

# setup /workspace/.opencode
for my $d ('.opencode', '.local', '.config', '.cache'){
    my $sd = "/workspace/$d";
    if(!-d $sd){
        mkdir($sd)
            or die "Failed to create directory $sd: $!";
    }
    chown(1000, 1000, $sd)
        or die "Error changing ownership of $sd to 1000: $!";
}

# copy skills (overwrite existing files)
my $skills_src = "/skills";
my $skills_dir = "/workspace/.opencode/skills";
if (-d $skills_src) {
    make_path($skills_dir) unless -d $skills_dir;
    copy_tree($skills_src, $skills_dir);
}

# If running as root and UID environment variable is set, use that UID
if($< == 0 and length($ENV{UID}//"")){
    local $! = 0;
    my $target_uid = $ENV{UID};
    # Drop to GID 986 109 992
    $) = "1000 986 992 109";
    $( = $);
    # Drop to the specified UID
    $> = $target_uid;
    $< = $>;
    die "Error setting UID to $target_uid: $!"
        if $!;
}

# If still running as root (no UID env var), default to UID 1000
if($< == 0){
    local $! = 0;
    # Drop to GID 986 109 992
    $) = "1000 986 992 109";
    $( = $);
    # Drop to UID 1000
    $> = 1000;
    $< = $>;
    die "Error setting UID to 1000: $!"
        if $!;
}

# Final safety check: ensure we're not running as root
die "Error: Running as root is not allowed"
    if $< == 0;

$ENV{XDG_CACHE_HOME} = "/workspace/.cache";
$ENV{PROMPT_COMMAND} = 'history -a';
$ENV{HISTFILE} = $history_path;

# Set HOME environment variable for node user
$ENV{HOME} = "/workspace";
$ENV{LOGNAME} = "node";
$ENV{PATH} = "$ENV{PATH}:$ENV{ROCM_PATH}/bin" if length($ENV{ROCM_PATH}//"");

# $ENV{BDIR} was mounted on /workdir/$BDIR
if($ENV{BDIR}){
    chdir("/workdir/$ENV{BDIR}")
        or die "Error chdir to /workdir/$ENV{BDIR}: $!\n";
} else {
    chdir("/workdir")
        or die "Error chdir to /workdir/: $!\n";
}

# Execute the actual opencode CLI with all provided arguments
exec("/home/node/.npm-global/bin/opencode", @ARGV)
    or die "Failed to exec: $!";
