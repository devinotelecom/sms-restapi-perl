package SmsClient;
use strict;
use warnings;
use JSON::XS ();
use LWP::UserAgent ();
use Carp qw(croak);
use URI ();
use HTTP::Request ();
use HTTP::Headers ();

our $AUTOLOAD;
our $VERSION = '0.02';
our $URL = 'https://integrationapi.net/rest';

our %ERROR_CODES = (
    200 => 'Operation Complete',
    400 => 'Argument Can Not Be Null Or Empty',
    400 => 'Invalid Argument',
    400 => 'Invalid Session ID',
    401 => 'UnauthorizedA ccess',
    403 => 'Not Enough Credits',
    400 => 'Invalid Operation',
    403 => 'Forbidden',
    500 => 'Gateway Error',
    500 => 'Internal Server Error',
);

sub __input_date {
    my %in = @_;
    return sub {
        if (ref $_ eq 'Date::EzDate') {
            $_ = $_->{"{year}-{month number base 1}-{day of month}T{hour}:{minute}:{second}"};
        } elsif (ref $_ eq 'DateTime') {
            $_ = $_->ymd . 'T' . $_->hms;
        } elsif ($_) {
            croak "Input parameter '$in{name}' has incorrect format"
                unless /\d\d\d\d\-\d\d\-\d\dT\d\d:\d\d:\d\d/;
        }
        return $in{mandatory};
    };    
}

our %RESOURCES = (
    init_session => {
        input => {
            login => 1,
            password => 1,
        },
        no_session_parameter => 1,
        method => 'GET',
        resource => 'User/SessionId',
        check => sub {
            croak "Server returned invalid response" unless defined and length == 36;
            $_[0]->{session_id} = $_;
        },
    },
    balance => {
        method => 'GET',
        resource => 'User/Balance',
        inflate => sub { chomp },
    },
    send => {
        input => {
            destinationAddress => 1,
            sendDate => __input_date(name => 'sendDate'),
            data => 1,
            sourceAddress => sub {
                if ($_) {
                    croak "Input parameter 'sourceAddress' has a maximum length of 15 digits or 11 latin characters"
                        unless /^\d{0,15}$/ or /^\w{0,11}$/;
                }
                return 1; # this parameter is mandatory
            },
            validity => sub {
                if ($_) {
                    croak "Input parameter 'validity' has to be an integer value"
                        if /\D/;
                }
                return; # this parameter is optional
            },
        },
        method => 'POST',
        resource => 'Sms/Send',
    },
    state => {
        input => {
            messageId => 1,
        },
        method => 'GET',
        resource => 'Sms/State',
    },
    get => {
        input => {
            minDateUTC => __input_date(name => 'minDateUTC', mandatory => 1),
            maxDateUTC => __input_date(name => 'maxDateUTC', mandatory => 1),
        },
        method => 'GET',
        resource => 'Sms/In',
    },
    statistics => {
        input => {
            startDateTime => __input_date(name => 'startDateTime', mandatory => 1),
            endDateTime => __input_date(name => 'endDateTime', mandatory => 1),
        },
        method => 'GET',
        resource => 'Sms/Statistics',
    },
);

$RESOURCES{send_by_timezone} = {
    input => {%{$RESOURCES{send}{input}}},
    method => 'POST',
    resource => 'Sms/SendByTimeZone',
};

$RESOURCES{send_bulk} = {
    input => {
        sendDate        => $RESOURCES{send}{input}{sendDate},
        data            => $RESOURCES{send}{input}{data},
        sourceAddress   => $RESOURCES{send}{input}{sourceAddress},
        validity        => $RESOURCES{send}{input}{validity},
        destinationAddresses => 1,
    },
    method => 'POST',
    resource => 'Sms/SendBulk',
};

sub DESTROY {1}

sub AUTOLOAD {
    my $self = shift;
    my %in = @_;
    (my $resource_name = $AUTOLOAD) =~ s/.*:://;
    croak "Invalid resource name '$resource_name'" unless exists $RESOURCES{$resource_name};
    my $res = $RESOURCES{$resource_name};
    croak "Invalid resource definition" unless $res->{method} and $res->{resource};
    
    my %request_params;
    if ($res->{input}) {
        foreach my $name (keys %{$res->{input}}) {
            my $mandatory = $res->{input}{$name};
            my $value = $in{$name};
            local $_ = $value;
            $mandatory = $mandatory->($value) if ref $mandatory;
            $value = $_ if $_;
            
            croak "Input parameter '$name' for resource '$resource_name' is not specified"
                if $mandatory and not defined $value;
                
            $request_params{$name} = $value;
        }
    }
    
    unless ($res->{no_session_parameter}) {
        croak "You have to initialize a new session id before you can call '$resource_name'"
            unless defined $self->{session_id};
        $request_params{sessionId} = $self->{session_id};     
    }
    
    my $uri = URI->new("$URL/$res->{resource}");
    $uri->query_form(%request_params);
    
    my $ua = LWP::UserAgent->new(
        agent => "Perl@{[ref($self)]}_v.$VERSION",
    );
    
    my $response = $ua->request(
        HTTP::Request->new(
            $res->{method} => $uri->as_string,
            HTTP::Headers->new(
                'Content-Type' => 'application/x-www-form-urlencoded',
                'Content-Length' => 0,
            ),
        )
    );
          
    unless ($response->is_success) {
        my $msg = exists $ERROR_CODES{$response->code}
            ? $ERROR_CODES{$response->code}
            : $response->status_line;
        
        croak "Error: $msg";
    }
    
    my $content = $response->content;
    
    if ($res->{inflate}) {
        local $_ = $content;
        my $rv = $res->{inflate}->($self);
        $content = $rv if $rv;
    } else {
        $content = JSON::XS->new->utf8->allow_nonref->decode($content);
    }
    
    if ($res->{check}) {
        local $_ = $content;
        $res->{check}->($self);
    }
    
    return $content;
}

sub new {
    my $class = shift;
    my %in = @_;
    my $self = { };
    bless $self, $class;
}



1;
__END__

=head1 NAME

[XXX: SmsClient is probably not the best name for a module. Consider naming after your service name. ]

SmsClient - Sending and receiving SMS messages via [XXX: your service name goes here]

=head1 SYNOPSIS

  use SmsClient;
  my $sms = SmsClient->new();
  
  # initialize a new session
  my $session_id = $sms->init_session(login => '123', password => '123');
  
  # get balance
  my $balance = $sms->balance();
  
  # send a message (neglecting recipient's timezone)
  my $message_id = $sms->send(
    destinationAddress => '79031234567',
    sourceAddress => '79037654321',
    data => 'message goes here'
  );
  
  # send a message (taking into account recipient's timezone)
  my $message_id = $sms->send_by_timezone(
    sendDate => '2010-08-28T10:00:00',
    destinationAddress => 79031234567,
    sourceAddress => '79037654321',
    data => 'message goes here'
  );
  
  # send a message to multiple recipients (neglecting recipients' timezones)
  my $message_id = $sms->send_bulk(
    destinationAddresses => ['79031234567', '79032345678'],
    sourceAddress => '79037654321',
    data => 'message goes here'
  );
  
  # fetch message state
  my $status = $sms->state(messageId => $message_id);
  
  # fetch incoming messages
  my $messages = $sms->get(
    minDateUTC => '2010-06-01T19:14:00',
    maxDateUTC => '2010-06-02T19:14:00',
  );
  
  # fetch statistics
  my $stats = $sms->statistics(
    startDateTime => '2012-01-18T00:00:00',
    endDateTime => '2012-01-19T00:00:00',
  );

=head1 INSTALLATION

SmsClient can be installed with the usual routine:

	perl Makefile.PL
	make
	make test
	make install

You can also just copy SmsClient.pm into your directory where your scripts are located.

=head1 DESCRIPTION

This module provides a convenient OO interface around a REST service for sending
and receiving SMS messages. Before you can start sending and receiving SMS messages
you have to create a new object

  my $sms = SmsClient->new();

and initialize a new session supplying your login and password

  $sms->init_session(login => '123', password => '123');

Once session is initialized it will be used in all subsequent requests.

=head1 Methods

=head2 init_session (login => ..., password => ... )

Takes login and password as its arguments. Initializes a new session and returns its value.

=head2 balance

Returns the balance of the user's account as a decimal number.

=head2 send (destinationAddress => ..., sourceAddress => ..., data => ..., [sendDate => ..., validity => ...])

There are three mandatory parameters: I<destinationAddress> is the message recipient's number in
the format country code + network code + phone code; I<sourceAddress> is the sender's address and has to be
no more than 11 latin characters or 15 digits long; I<data> - message text.
Optional parameters: I<sendDate> - the time and date at which the message should be sent (ex. 2010-06-01T19:14:00);
I<validity> - message's time to live which is specified in minutes. Returns an arrayref containg
a list of message ids.

=head2 send_by_timezone (destinationAddress => ..., sourceAddress => ..., data => ..., [sendDate => ..., validity => ...])

The same as C<send> method with the exception that I<sendDate> works in relation to message
recipient's timezone. I.e. if you want your message to be delivered at 10am recipient's time, you
should specify its value like this '2010-06-01T10:00:00'

=head2 send_bulk (destinationAddresses => ..., sourceAddress => ..., data => ..., [sendDate => ..., validity => ...])

Similar to C<send> method but can take multiple recipients.

    $sms->send_bulk(destinationAddresses => [1111111, 2222222, 333333] ...

=head2 state(message_id)

Takes one argument which must be a message id returned by one of C<send*> methods. Returns
a hashref describing the status of the message.

=head2 get (minDateUTC => ..., maxDateUTC => ...)

Fetch incoming messages for the specified time period. Returns an arrayref.

=head2 statistics (startDateTime => ..., endDateTime => ...)

Fetch statistics for the specified time period. Returns an hashref.

=head1 Caveats

Since this program works over a network, any method may fail causing your script to die.
You may wish to wrap method calls in C<eval> blocks and catch exceptions.

    eval {
      $sms->send(...);
    };
    if ($@) {
       
    }

For your convenience, every parameter which expects you to provide a date/time like I<sendDate> or I<minDateUTC>
may also accept a C<Date::ezDate> or C<DateTime> object.

=head1 AUTHOR

    A.Sergei <asergei@lenta.ru>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 [XXX: your company name goes here]

=cut
