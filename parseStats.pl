#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use Data::Dumper;
use File::Slurp;
use POSIX qw(strftime);
use DateTime;
use DateTime::Format::Strptime;

my $json = './nm-mock.json';

my %roles = (
	'mm' => 'None',
	'mm_ga' => 'None, with guest account',
	'dm' => 'Debian Maintainer',
	'dm_ga' => 'Debian Maintainer, with guest account',
	'dd_u' => 'Debian Developer, uploading',
	'dd_nu' => 'Debian Developer, non-uploading',
	'dd_e' => 'Debian Developer, emeritus',
	'dm_e' => 'Debian Maintainer, emeritus',
	'dd_r' => 'Debian Developer, removed',
	'dm_r' => 'Debian Maintainer, removed',
);

my $now = DateTime->now;
my $parser = DateTime::Format::Strptime->new(
	pattern => '%Y-%m-%d %H:%M:%S',
	on_error => 'croak',
);

my $hashTable = decode_json(File::Slurp::read_file("$json"));

my $new = 0;
my $am = 0;
my $am_hold = 0;
my $fd = 0;
my $fd_hold = 0;
my $dam = 0;
my $dam_hold = 0;
my $dam_naccnt = 0;

foreach my $object (@$hashTable) {
	foreach my $process (@{$object->{'processes'}}) {
		if($process->{'progress'} =~ m/^app_new$/) {
			$new++;
		}
		elsif($process->{'progress'} =~ m/^am$/) {
			$am++;
		}
		elsif($process->{'progress'} =~ m/^am_hold$/) {
			$am_hold++;
		}
		elsif($process->{'progress'} =~ m/^fd_hold$/) {
			$fd_hold++;
		}
		elsif($process->{'progress'} =~ m/^am_ok$/) {
			$fd++;
		}
		elsif($process->{'progress'} =~ m/^dam_hold$/) {
			$dam_hold++;
		}
		elsif($process->{'progress'} =~ m/^fd_ok$/) {
ss (@{$object->{'processes'}}) {dam++;
		}
		elsif($process->{'progress'} =~ m/^dam_ok$/) {
			$dam_naccnt++;
		}
		foreach my $log (@{$process->{'log'}}) {
			my $dt = $parser->parse_datetime($log->{'logdate'});
			my $diff = $now-$dt;
			if($diff->{'months'}==0 && $diff->{'days'}<=7) {
				if($log->{'progress'} =~ m/^app_new$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") asked to enter the process.\n";
				}
				elsif($log->{'progress'} =~ m/^app_rcvd$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") replied to initial mail.\n";
				}
				elsif($log->{'progress'} =~ m/^app_hold$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") on hold before entering the queue.\n";
				}
				elsif($log->{'progress'} =~ m/^adv_rcvd$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") received enough advocacies.\n";
				}
				elsif($log->{'progress'} =~ m/^app_ok$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") had their advocacies approved.\n";
				}
				elsif($log->{'progress'} =~ m/^am_rcvd$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") waiting for AM to confirm.\n";
				}
				elsif($log->{'progress'} =~ m/^am$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") interacting with an AM.\n";
				}
				elsif($log->{'progress'} =~ m/^am_hold$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") had AM put application on hold.\n";
				}
				elsif($log->{'progress'} =~ m/^am_ok$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") approved by AM.\n";
				}
				elsif($log->{'progress'} =~ m/^fd_hold$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") had FD put application on hold.\n";
				}
				elsif($log->{'progress'} =~ m/^fd_ok$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") had AM report approved by FD.\n";
				}
				elsif($log->{'progress'} =~ m/^dam_hold$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") had DAM put application on hold.\n";
				}
				elsif($log->{'progress'} =~ m/^dam_ok$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") had application accepted by DAM.\n";
				}
				elsif($log->{'progress'} =~ m/^done$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") has completed the process and had their account created.\n";
				}
				elsif($log->{'progress'} =~ m/^cancelled$/) {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") had their process cancelled.\n";
				}
				else {
					print $object->{'key'} . " (" . $roles{$process->{'applying_for'}} . ") has had an unknown status change: " . $log->{'progress'} . "\n";
				}
			}
		}
	}
}
print "New: $new | AM: $am (held $am_hold) | FD: $fd ($fd_hold) | DAM $dam ($dam_hold) + $dam_naccnt\n";
