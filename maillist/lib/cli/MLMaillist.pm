package MLMaillist;

require Exporter;
@ISA    = qw(Exporter);
# Find the lib directory above the location of myself. Should be the same directory I'm in
# # This isn't necessary if these libs get installed in a standard perl lib location
use FindBin;
use lib "$FindBin::Bin/..";
use MLRestClient;
use MLRestMaillist;
use MLMP1Server;
use MLMaillistFormatter;

@KEYS = qw(name type status owner actdate expdate newsfeed desc opt ats mod email);
@MANAGERS = undef;

sub new {
    my $class = shift;
    my $restMaillist  = shift;
    my $service = shift;
	my $self = {};
	bless $self, $class;
	$self->{MLSERVICE} = $service;
	$self->{RESTCLIENT} = $service->{SERVICE};
	$self->{RESTMAILLIST} = $restMaillist;
	print '************************\n' if $main::TEST;
	print $restMaillist->toString() if $main::TEST;
	print '************************\n' if $main::TEST;
	my $username = $main::LOGIN;
	$self->{type} = calculateType($restMaillist);
	return $self;
}

sub calculateType {
    my $restMaillist = shift;
    if ($restMaillist->isCourselist()) { return 's' };
    if ($restMaillist->localSubscriptionPolicy() == 1) { return 'o' };
    return 'c';
}
	
sub name {
	my $self = shift;
	return $self->{RESTMAILLIST}->name();
}

sub status {
	my $self = shift;
	return $self->{RESTMAILLIST}->status();
}

sub type {
	my $self = shift;
	return $self->{type};
}

sub owner {
	my $self = shift;
	return $self->{RESTMAILLIST}->owner();
}

sub actdate {
	my $self = shift;
	return $self->{RESTMAILLIST}->activationDate();
}

sub expdate {
	my $self = shift;
	return $self->{RESTMAILLIST}->expireDate();
}

sub newsfeed {
	my $self = shift;
	return $self->{RESTMAILLIST}->newsfeed();
}

sub description {
	my $self = shift;
	return $self->{RESTMAILLIST}->desc();
}

#sub options {
#	my $self = shift;
#	return $self->{opt};
#}

sub allowedToSend {
	my $self = shift;
	my $username = shift;
	
	my $senderPermission = $self->{RESTCLIENT}->getSenderPermission($self->{RESTMAILLIST}, $username, 0);
	my $ats = $senderPermission->isAllowedToSend();
	print $username.' ats: '.$ats."\n" if $main::TEST;
	return $ats;
}

sub membersAllowedToSend {
	my $self = shift;

    return $self->{RESTMAILLIST}->localDefaultAllowedToSend() eq 'true' ? 1 : 0;
}

sub moderated {
	my $self = shift;
	return $self->{RESTMAILLIST}->moderator() ne '' ? 1 : 0;
}

sub subscribeByEmail {
	my $self = shift;
	return $self->{RESTMAILLIST}->allowedToSubscribeByEmail() eq 'true' ? 1 : 0;
}

sub isCourselist {
	my $self = shift;
	return $self->{type} eq 's' ? 1 : 0;
}

sub isOpen {
	my $self = shift;
	return $self->{type} eq 'o' ? 1 : 0;
}

sub isClosed {
	my $self = shift;
	return $self->{type} eq 'c' ? 1 : 0;
}

sub isRestricted {
	my $self = shift;
	return $self->{RESTMAILLIST}->localSenderPolicyCodeString() eq 'RESTRICTED' ? 1 : 0;
}

sub note {
	my $self = shift;
	return $self->{RESTMAILLIST}->noteText();
}

sub managers {
	my $self = shift;
	my @managers = $self->{RESTMAILLIST}->managers();
	my @addrs = ();
	foreach my $manager (@managers) {
	   push @addrs, $manager->canonicalAddress();
	}
	return \@addrs;
}

sub isManager {
  my $self = shift;
  my $man = shift;
  my $managers = $self->managers();
  return grep( $_ eq $man, @$managers ) if $managers;
  return 0;
}

sub allowedSenders {
  my $self = shift;
  my @allowed = $self->{RESTMAILLIST}->allowed();
	my @addrs = ();
	foreach my $allowed (@allowed) {
	   push @addrs, $allowed->canonicalAddress();
	}
	return \@addrs;
}

sub deniedSenders {
  my $self = shift;
  my @denied = $self->{RESTMAILLIST}->denied();
	my @addrs = ();
	foreach my $denied (@denied) {
	   push @addrs, $denied->canonicalAddress();
	}
	return \@addrs;
}

sub members {
  my $self = shift;  
  my @members = $self->{RESTMAILLIST}->members();
  if (!defined(@members)) {
     print "Fetch of members failed\n";
     return 0;
  }
  @addrs = ();
  foreach $member (@members) {
     push @addrs, $member->canonicalAddress() unless _isAutoGenerated($member);
  }
  my @sorted = sort @addrs;
  return \@sorted;
}

sub courseMembers {
  my $self = shift;
  return [] unless $self->isCourselist();
  my @members = $self->{RESTMAILLIST}->members();
  if (!defined(@members)) {
     print "Fetch of members failed\n";
     return 0;
  }
  @addrs = ();
  foreach $member (@members) {
     push @addrs, $member->canonicalAddress() if _isAutoGenerated($member);
  }
  my @sorted = sort @addrs;
  return \@sorted;
}

sub subscribe {
  my $self = shift;
  my $address = shift;
  print "In MLMaillist->subscribe $address\n" if DEBUG;
  my $newMember = $self->{RESTCLIENT}->addMember($self->{RESTMAILLIST}, $address);
  print "Error adding member\n" unless $newMember;
  return $newMember ? 'ok' : 0;
}

sub unsubscribe {
  my $self = shift;
  my $address = shift;
  print "In MLMaillist->unsubscribe $address\n" if DEBUG;
  my $mlRestMember = $self->mlRestMemberWithAddress( $address );
  return 0 unless $mlRestMember;
  $self->{RESTCLIENT}->deleteMember($mlRestMember);
  return 'ok';
}

sub addAllowed {
  my $self = shift;
  my $address = shift;
  my $maillist = $self->{RESTMAILLIST};
  my $result = $self->{RESTCLIENT}->setSenderPermission($maillist, $address, 'true');
  $self->{RESTMAILLIST} = $self->{RESTCLIENT}->getMaillistById($maillist->{'id'});
  return $result ? 'ok' : 0;
}
  
sub deleteAllowed {
  my $self = shift;
  my $address = shift;
  my $maillist = $self->{RESTMAILLIST};
  my $result = $self->{RESTCLIENT}->setSenderPermission($maillist, $address, 'false');
  $self->{RESTMAILLIST} = $self->{RESTCLIENT}->getMaillistById($maillist->{'id'});
  return $result ? 'ok' : 0;
}
  
sub addDenied {
  my $self = shift;
  my $address = shift;
  my $maillist = $self->{RESTMAILLIST};
  my $result = $self->{RESTCLIENT}->setSenderPermission($maillist, $address, 'false');
  $self->{RESTMAILLIST} = $self->{RESTCLIENT}->getMaillistById($maillist->{'id'});
  return $result ? 'ok' : 0;
}
  
sub deleteDenied {
  my $self = shift;
  my $address = shift;
  my $maillist = $self->{RESTMAILLIST};
  my $result = $self->{RESTCLIENT}->setSenderPermission($maillist, $address, 'true');
  $self->{RESTMAILLIST} = $self->{RESTCLIENT}->getMaillistById($maillist->{'id'});
  return $result ? 'ok' : 0;
}

sub get {
  my $self = shift;
  my $key = shift;
  
  return $self->{RESTMAILLIST}->{$key};
}

sub set {
  my $self = shift;
  my $value = shift;
  my $key = shift;
  
  my $maillist = $self->{RESTMAILLIST};
  %contentHash = (
    $key => $value
  );
  $result = $maillist->modify(\%contentHash);
  return $result ? 'ok' : 0;
}

sub setOpen {
    my $self = shift;

    my $rc = $self->set('OPEN', 'localSubscriptionPolicyCodeString');
    return 0 unless $rc=~/^ok/;
    $rc = $self->set('OPEN', 'externalSubscriptionPolicyCodeString');
    return 0 unless $rc=~/^ok/;
    return 'ok';
}

sub setClosed {
    my $self = shift;

    my $rc = $self->set('BYREQUEST', 'localSubscriptionPolicyCodeString');
    return 0 unless $rc=~/^ok/;
    $rc = $self->set('BYREQUEST', 'externalSubscriptionPolicyCodeString');
    return 0 unless $rc=~/^ok/;
    return 'ok';
}

#
# private functions
#

# sub _managerString {
#   my $self = shift;
#   my $managersRef = $self->managers();
#   if ($managersRef==0) {
#     return "";
#   } else {
#     my @managers = @$managersRef;
#     unless (scalar(@managers)) {
#       return "(No managers assigned)";
#     }
#     return (join ', ',@managers)."  (".$self->name()."-request)";
#   }
# }

sub _isAutoGenerated {
  my $member =shift;
  return $member->isLocalMember() && $member->autoGenerated() eq 'true';
}

sub mlRestMemberWithAddress {
  my $self = shift;
  my $address = shift;
  my @members = $self->{RESTMAILLIST}->members();
  if (!defined(@members)) {
     print "Fetch of members failed\n";
     return 0;
  }
  @addrs = ();
  foreach $member (@members) {
     if ($self->{RESTCLIENT}->canonicalAddress($address) eq $member->canonicalAddress()) {
        return $member;
     }
  }
  return undef;
}

sub display {
  my $self = shift;
  
  my $formatter = new MLMaillistFormatter($self);
  $formatter->display();
}

# sub display2 {
#   my $self = shift;
#   my $type;
#   my $res = "Unrestricted sender";
#   my $t = $self->{type};
#   if ($t eq "c") { $type = "closed"; }
#   elsif ($t eq "o") {$type = "open"; }
#   elsif ($t eq "s") {$type = "courselist"; }
#   else { $type = $t; }
#   
#   $res = 'Restricted sender' if $self->isRestricted();
#   my $mats = $self->membersAllowedToSend() ? "Members allowed to send" : "";
#   my $email = $self->subscribeByEmail ? "Anyone can subscribe via email" : "" ;
#   
#   my $managers = $self->_managerString();
#   my $desc = $self->description();
#   
#   format LISTINFO =
# List Name:    @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#               $self->name()
# Status:       @<<<<<<<<<<<<<<
#               $self->status()
# Type:         @<<<<<<<<<<<<<<
#               $type
# Owner:        @<<<<<<<<
#               $self->owner()
# Manager@<<:   ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#        "(s)"  $managers
# ~             ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#               $managers
# Description:  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#               $desc
# ~             ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#               $desc
# ~             ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ...
#               $desc
# Options:      ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#               $res
# ~             ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#               $mats
# ~             ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#               $email
# Activated On: @<<<<<<<<<
#               $self->actdate()
# ~Expires On:   @<<<<<<<<<
#               $self->expdate()
#               
# .
#   STDOUT->format_name("LISTINFO");
#   write;
#   STDOUT->format_name("STDOUT");
#   
# }
