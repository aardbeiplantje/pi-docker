#!/usr/bin/perl

use File::Path qw(make_path);

# Set process name to 'opencode' for cleaner process listings
$0 = 'opencode';

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

if (-d $ENV{BDIR}) {
    chdir($ENV{BDIR})
        or die "Failed to change directory to $ENV{BDIR}: $!";
}

# setup /workspace/tmp, the symlink from /tmp to /workspace/tmp is already there
mkdir("/workspace");
my $tmp_path = "/workspace/tmp";
if(!-d $tmp_path){
    mkdir($tmp_path, 0777)
        or die "Failed to create directory $tmp_path: $!";
    chown(1000, 1000, $tmp_path)
        or die "Error changing ownership of $tmp_path to 1000: $!";
    chmod(01777, $tmp_path)
        or die "Error setting permissions of $tmp_path to 1777: $!";
}
rmdir("/tmp")
    or die "Failed to remove existing /tmp directory: $!";
symlink($tmp_path, "/tmp")
    or die "Failed to create symlink from $tmp_path to /tmp: $!";

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

# copy skills
my $skills_dir = "/workspace/.opencode";
if(-d '/skills'){
    system("cp -a /skills $skills_dir/");
}

$ENV{XDG_CACHE_HOME} = "/workspace/.cache";

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

$ENV{PROMPT_COMMAND} = 'history -a';
$ENV{HISTFILE} = $history_path;

# Set HOME environment variable for node user
$ENV{HOME} = "/workspace";
$ENV{LOGNAME} = "node";
$ENV{OPENCODE_AUTO_SHARE} = $opencode_cfg;
$ENV{PATH} = "$ENV{PATH}:$ENV{ROCM_PATH}/bin" if length($ENV{ROCM_PATH}//"");

# Execute the actual opencode CLI with all provided arguments
exec("/home/node/.npm-global/bin/opencode", @ARGV)
    or die "Failed to exec: $!";
