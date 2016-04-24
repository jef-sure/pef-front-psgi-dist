package PEF::Front::Session;

use strict;
use warnings;
use PEF::Front::Config;
use MLDBM::Sync;
use MLDBM qw(GDBM_File Storable);
use Fcntl qw(:DEFAULT :flock);
use Digest::SHA qw(sha1_hex);
use Scalar::Util 'blessed';

sub _secure_value {
	open my $urand, '<', '/dev/urandom' or die "can't open /dev/urandom: $!";
	read ($urand, my $buf, 32);
	close $urand;
	return sha1_hex($buf);
}

sub _key ()     { 0 }
sub _session () { 1 }
sub _expires () { 0 }
sub _data ()    { 1 }

sub new {
	my ($class, $request) = @_;
	my $key = (
		blessed($request) ? $request->param(cfg_session_request_field())
		  || $request->cookies->{cfg_session_request_field()}
		: ref ($request) ? $request->{cfg_session_request_field()}
		:                  $request
	);
	$key ||= _secure_value;
	my $self = bless [$key, [time + cfg_session_ttl, {}]], $class;
	$self->load;
	$self;
}

sub load {
	my $self = $_[0];
	my %session_db;
	my $sobj = tie (%session_db, 'MLDBM::Sync', cfg_session_db_file, O_CREAT | O_RDWR, 0660) or die "$!";
	$sobj->Lock;
	my $session = $session_db{$self->[_key]};
	if ($session && $session->[_expires] > time) {
		$self->[_session]    = $session;
		$session->[_expires] = time + cfg_session_ttl;
	} else {
		delete $session_db{$self->[_key]};
	}
	$sobj->UnLock;
}

sub store {
	my $self = $_[0];
	tie (my %session_db, 'MLDBM::Sync', cfg_session_db_file, O_CREAT | O_RDWR, 0660) or die "$!";
	$self->[_session][_expires] = time + cfg_session_ttl;
	$session_db{$self->[_key]} = $self->[_session];
}

sub destroy {
	my $self = $_[0];
	$self->[_session][_expires] = 0;
	tie (my %session_db, 'MLDBM::Sync', cfg_session_db_file, O_CREAT | O_RDWR, 0660) or die "$!";
	delete $session_db{$self->[_key]};
}

sub data {
	my ($self, $data) = @_;
	if (defined ($data)) {
		$self->[_session][_data] = $data;
	}
	$self->[_session][_data];
}

sub key {
	my ($self) = @_;
	$self->[_key];
}

sub DESTROY {
	my $self = $_[0];
	if ($self->[_session][_expires] > time) {
		$self->store;
	} else {
		$self->destroy;
	}
}

1;
