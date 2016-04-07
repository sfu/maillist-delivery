#!/usr/local/bin/perl

use lib '/opt/amaint/prod/lib';
use Amaintr;
use Utils;
use ICATCredentials;

my $cred  = new ICATCredentials('amaint.json')->credentialForName('amaint');
my $TOKEN = $cred->{'token'};
$main::amaintr = new Amaintr( $TOKEN, 0 );
my $result = $main::amaintr->fireImport();
exit 0;