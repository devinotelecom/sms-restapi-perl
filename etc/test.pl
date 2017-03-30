#!/usr/bin/perl
use strict;
no warnings 'redefine';
use Data::Dumper;
use SmsClient;

$| = 1;

our $LOGIN = 'Test_MC';
our $PASSWORD = '1q2w3e4r';
our $SENDER = 'TestMC';
our $RECIPIENT = '79031234567';


use SmsClient;
my $sms = SmsClient->new();
print "Object created\n";


# initialize a new session
my $session_id = $sms->init_session(login => $LOGIN, password => $PASSWORD);
print "Session initialized: $session_id\n";


# get balance
my $balance = $sms->balance();
print "Balance: $balance\n";


# send a message (neglecting recipient's timezone)
my $message_id = $sms->send(
  destinationAddress => $RECIPIENT,
  sourceAddress => $SENDER,
  data => 'simple простое'
);

print "SMS via 'send'\n";
print Dumper($message_id);

# send a message (taking into account recipient's timezone)
$message_id = $sms->send_by_timezone(
  sendDate => '2012-08-29T01:12:00',
  destinationAddress => $RECIPIENT,
  sourceAddress => $SENDER,
  data => 'timezone с учетом времени'
);

print "SMS via 'send_by_timezone'\n";
print Dumper($message_id);

# send a message to multiple recipients (neglecting recipients' timezones)
$message_id = $sms->send_bulk(
  destinationAddresses => [$RECIPIENT],
  sourceAddress => $SENDER,
  data => 'простое simple'
);

print "SMS via 'send_bulk'\n";
print Dumper($message_id);

# fetch message state
my $status = $sms->state(messageId => $message_id->[0]);

print "Status of $message_id->[0] ($status->{StateDescription})\n";
print Dumper($status);

# fetch incoming messages
my $messages = $sms->get(
  minDateUTC => '2012-07-01T19:14:00',
  maxDateUTC => '2012-08-02T19:14:00',
);

print "Inbox\n";
print Dumper($messages);

# fetch statistics
my $stats = $sms->statistics(
  startDateTime => '2012-07-18T00:00:00',
  endDateTime => '2012-08-19T00:00:00',
);

print "Stats\n";
print Dumper($stats);

print "All done!\n";