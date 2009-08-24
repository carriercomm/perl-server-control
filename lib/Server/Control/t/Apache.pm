package Server::Control::t::Apache;
use base qw(Server::Control::t::Base);
use File::Path;
use File::Slurp qw(write_file);
use File::Which;
use POSIX qw(geteuid getegid);
use Server::Control::Apache;
use Test::Most;
use strict;
use warnings;

sub check_httpd_binary : Test(startup) {
    my $self = shift;

    if ( !scalar( which('httpd') ) ) {
        $self->SKIP_ALL("cannot find httpd in path");
    }
}

sub create_ctl {
    my ( $self, $port, $temp_dir ) = @_;

    mkpath( "$temp_dir/logs", 0, 0775 );
    mkpath( "$temp_dir/conf", 0, 0775 );
    my $conf = "
        ServerName mysite.com
        ServerRoot $temp_dir
        Listen     $port
        PidFile    $temp_dir/logs/my-httpd.pid
        LockFile   $temp_dir/logs/accept.lock
        ErrorLog   $temp_dir/logs/my-error.log
        StartServers 2
        MinSpareServers 1
        MaxSpareServers 2
    ";
    write_file( "$temp_dir/conf/httpd.conf", $conf );
    return Server::Control::Apache->new( root_dir => $temp_dir );
}

sub test_build_default : Test(5) {
    my $self = shift;

    my $ctl      = $self->{ctl};
    my $temp_dir = $self->{temp_dir};
    is( $ctl->conf_file, "$temp_dir/conf/httpd.conf",
        "determined conf_file from server root" );
    is( $ctl->bind_addr, "localhost",   "determined bind_addr from default" );
    is( $ctl->port,      $self->{port}, "determined port from conf file" );
    is( $ctl->pid_file, "$temp_dir/logs/my-httpd.pid",
        "determined pid_file from conf file" );
    like(
        $ctl->error_log,
        qr{$temp_dir/logs/my-error.log},
        "determined error_log from conf file"
    );
}

sub test_build_alternate : Test(5) {
    my $self = shift;

    my $temp_dir = $self->{temp_dir} . "/alternate";
    mkpath( "$temp_dir/conf", 0, 0775 );
    my $port = $self->{port} + 1;
    my $conf = "
        ServerRoot $temp_dir
        Listen 1.2.3.4:$port
    ";
    my $conf_file = "$temp_dir/conf/httpd.conf";
    write_file( $conf_file, $conf );
    my $ctl = Server::Control::Apache->new( conf_file => $conf_file );
    is( $ctl->root_dir,  $temp_dir, "determined root_dir from conf file" );
    is( $ctl->bind_addr, "1.2.3.4", "determined bind_addr from conf file" );
    is( $ctl->port,      $port,     "determined port from conf file" );
    is( $ctl->pid_file, "$temp_dir/logs/httpd.pid",
        "determined pid_file from default" );
    like( $ctl->error_log, qr{$temp_dir/logs/error.log},
        "determined error_log from default" );
}

sub test_missing_params : Test(1) {
    my $self = shift;
    my $port = $self->{port};

    throws_ok {
        Server::Control::Apache->new(
            port     => $self->{port},
            pid_file => $self->{temp_dir} . "/logs/httpd.pid"
        )->conf_file();
    }
    qr/no conf_file or root_dir specified/;
}

1;