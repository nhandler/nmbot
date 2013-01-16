#!/usr/bin/perl

use strict;
use warnings;
use vars qw($VERSION %IRSSI);
require LWP::UserAgent;
use JSON;
use Data::Dumper;

use Irssi;
$VERSION = '0.01';
%IRSSI = (
	authors		=>	'Nathan Handler',
	contact		=>	'nhandler@debian.org',
	name		=>	'NMBot',
	description	=>	'NMBot updates the /topic and displays notifications related to the Debian NM Process',
	license		=>	'GPLv3+',
);

my $debug = 1;	# Set to a true value (1) to print extra information within irssi

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

my %stages = (
	'app_new' => 'Applicant asked to enter the process',
	'app_rcvd' => 'Applicant replied to initial mail',
	'app_hold' => 'On hold before entering the queue',
	'adv_rcvd' => 'Received enough advocacies',
	'app_ok' => 'Advocacies have been approved',
	'am_rcvd' => 'Waiting for AM to confirm',
	'am' => 'Interacting with an AM',
	'am_hold' => 'AM put application on hold',
	'am_ok' => 'AM approved the applicant',
	'fd_hold' => 'FD puts application on hold',
	'fd_ok' => 'FD approved the AM report',
	'dam_hold' => 'DAM puts application on hold',
	'dam_ok' => 'DAM accepted the applicant',
	'done' => 'Process has completed successfully (account was created)',
	'cancelled' => 'Process has been canceled',
);

Irssi::settings_add_str('nmbot', 'nmbot_json', 'https://nm.debian.org/public/stats/latest?days=30&json=true');
Irssi::settings_add_str('nmbot', 'nmbot_channel', '#debian-newmaint');
Irssi::settings_add_str('nmbot', 'nmbot_last_announce', '0');
Irssi::settings_add_str('nmbot', 'nmbot_topic_prefix', 'New nm.d.o up \o/ | NM := New Member | For packaging/sponsor questions, please join #debian-mentors | Queues: ');

Irssi::timeout_add(60000, 'main','');	#Run main() every 1 minute

main();

# Downloads the JSON feed from nm.debian.org containing all of the data
# Parameters: none
# Returns the JSON file or nothing (if error)
sub getJson {
	my $url = Irssi::settings_get_str('nmbot_json');
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
	my $response = $ua->get("$url");
    if ($response->is_success) {	# If we sucessfully downloaded the file...
        return decode_json($response->decoded_content);		# Return the JSON decoded into a hash
    }
    else {	# If we failed to download the file...
        Irssi::print("Failed to get $url: " . $response->status_line);	# Display an error message
    }
}

# Parameter: $topic : A string that will be set as the new IRC channel topic
# Returns nothing, just changes the channel topic
sub setTopic {
	my($topic) = @_;

	my($server) = Irssi::server_find_tag('oftc');
	my($channel) = Irssi::settings_get_str('nmbot_channel');
	$server->send_raw("TOPIC $channel :$topic");
}

# Get and return the IRC channel topic
# Takes no parameters
sub getTopic {
	my($server) = Irssi::server_find_tag('oftc');
	my($channel) = $server->channel_find(Irssi::settings_get_str('nmbot_channel'));;
	my($topic) = $channel->{'topic'};

	return $topic;
}

# Parameter: $json : Decoded JSON hash
# The JSON contains a field specifying what the IRC channel topic should be
# Return that field as a string
sub getTopicFromJson {
	my($json) = @_;

	return $json->{'irc_topic'};
}

# Parameter: $json : Decoded JSON hash
# Checks if the current channel topic is set correctly
# If it is not, we call setTopic() to set it
# If it is, we do nothing
# Returns nothing
sub updateTopic {
	my $json = shift;
	my $newTopic = getTopicFromJson($json);
	my $topic = getTopic();
	my $prefix = Irssi::settings_get_str('nmbot_topic_prefix');
	$topic = "$topic";
	$newTopic = "$prefix$newTopic";
	Irssi::print("Old Topic: $topic")	if($debug);
	Irssi::print("New Topic: $newTopic")	if($debug);

	if($topic ne $newTopic) {
   		Irssi::print("Changing Topic to $newTopic")	if($debug);
		setTopic($newTopic);
	}
	else {
    	Irssi::print("Not changing topic")	if($debug);
	}
}

# Parameter: $json : Decoded JSON hash
# Displays a message in the IRC channel for each event in the JSON file
# Includes checks to prevent displaying the same event multiple times
# Returns nothing
sub announce {
	my $json = shift;
	my($server) = Irssi::server_find_tag('oftc');
	my($channel) = Irssi::settings_get_str('nmbot_channel');
	foreach my $event (@{$json->{'events'}}) {
		if($event->{'status_changed_ts'} > Irssi::settings_get_str('nmbot_last_announce')) {
			if($event->{'type'} eq "status") {
				$server->command("MSG $channel " . $event->{'fn'} . " (" . $event->{'key'} . ") Status changed to: " . $roles{$event->{'status'}});
			}
			elsif($event->{'type'} eq "progress") {
				$server->command("MSG $channel " . $event->{'fn'} . " (" . $event->{'key'} . ") Progress changed to: " . $stages{$event->{'progress'}});
			}
			else {
				Irssi::print("Unknown Type (" . $event->{'type'} . ") for " . $event->{'key'});
			}
		}
		else {
			Irssi::print("NOT Announcing: " . $event->{'key'})	if($debug);
		}
	}
	Irssi::settings_set_str('nmbot_last_announce', time);
}

# Parameters: none
# This function is automatically called every minute
# Returns nothing
sub main {
	my $json = getJson();
	announce($json);
	updateTopic($json);
}
