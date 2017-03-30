use 5.014002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'SmsClient',
    VERSION_FROM      => 'lib/SmsClient.pm', # finds $VERSION
    PREREQ_PM         => {
		"JSON::XS" => 0,
		"LWP::UserAgent" => 0,
		"Net::SSLeay" => 0,
		"LWP::Protocol::https" => 0,
	}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/SmsClient.pm', # retrieve abstract from module
       AUTHOR         => 'A.Sergei <asergei@lenta.ru>') : ()),
);
