#!/usr/bin/env perl

use strict;
use warnings;
use threads;
use IO::Socket::INET;
use POSIX qw(strftime);

# variables and dictionaries {{{
# $| = 1; # auto-flush socket

my $interval = 0.1;

my %master = (
        "host"     => '0.0.0.0',
        "port"     => 57001,
        "protocol" => 'tcp',
        "max_conn" => 5,
        "reuse"    => 1,
);

my %slave = (
        # "ip"       => '172.16.19.30',
        "ip"       => '127.0.0.1',
        "port"     => 57002,
        "protocol" => 'tcp',
);
# }}}

# helper functions {{{
sub get_timestamp {
    return strftime "%Y-%m-%d %H:%M:%S", localtime;
}
# }}}

# socket server {{{
sub main_server {
	my $timestamp = get_timestamp();
	my $server = IO::Socket::INET->new(
		LocalHost => $master{'host'},     # Listen on all network interfaces
		LocalPort => $master{'port'},     # Port number
		Proto     => $master{'protocol'}, # Protocol
		Listen    => $master{'max_conn'}, # Max connections in queue
		Reuse     => $master{'reuse'},    # Allow socket reuse
	) or die "$timestamp: Could not create server socket: $!";

	print "$timestamp: Server listening on port $master{'port'}...\n";

	while (1) {
		$timestamp = get_timestamp();
		my $client = $server->accept();

		# print "$timestamp: Connection received from " . $client->peerhost() . "\n";

		eval {

			my $data = pack("C*", 0x01, 0x02, 0x03, 0x04);
			$client->send($data);

			$client->close();
			sleep($interval);
		};

		if ($@) {
			print "$timestamp: [connection lost] host: $master{'host'}, backup: $slave{'ip'}";
		}

		undef $client;
	}

	$server->close();
}
# }}}

# socket client {{{
sub main_client {
	my $timestamp = get_timestamp();

	# Create a socket to connect to the server
	my $client;
	print "$timestamp: Server waiting on port $slave{'port'}...\n";
	while (1) {
		eval {
			$client = IO::Socket::INET->new(
				PeerHost => $slave{'ip'},
				PeerPort => $slave{'port'},
				Proto    => $slave{'protocol'}
			) or die "$timestamp: Could not connect to server: $!";

			# print "$timestamp: Connected to server at $slave{'ip'}:$slave{'port'}\n";

			# Read the message sent by the server
			$timestamp = get_timestamp();
			my $response = <$client>;
			if (defined $response) {
				# chomp $response;
				# print "$timestamp: Response from server: $response\n";
			} else {
				warn "$timestamp: backup server went down!!!\n";
			}
			undef $client;
			sleep($interval);
		};
	}
	$client->close();

}

# }}}

# main section {{{

my $main_server_thread = threads->create(\&main_server);
my $main_client_thread = threads->create(\&main_client);
$main_client_thread->join();
$main_server_thread->join();

# my $pid = fork();
# if (!defined $pid) {
# 	die "Failed to fork: $!";
# } elsif ($pid == 0) {
# 	# Child process runs function1
# 	main_server();
# 	exit(0);  # End child process
# } else {
# 	# Parent process runs function2
# 	main_client();
# 	# Wait for the child process to finish
# 	waitpid($pid, 0);
# 	print "Both functions have finished.\n";
# }

# }}}

