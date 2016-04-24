package PEF::Front::Headers;
use strict;
use warnings;
use PEF::Front::Config;
use Time::Duration::Parse;
use Scalar::Util qw(blessed);
use Encode;
use utf8;

sub new {
	my $self = bless {}, $_[0];
	for (my $i = 1; $i < @_; $i += 2) {
		if (blessed($_[$i]) && $_[$i]->isa("PEF::Front::Headers")) {
			for my $fk (keys %{$_[$i]}) {
				if ('ARRAY' eq ref $_[$i]->{$fk}) {
					@{$self->{$fk}} = @{$_[$i]->{$fk}};
				} else {
					$self->{$fk} = $_[$i]->{$fk};
				}
			}
			++$i;
			redo;
		}
		$self->add_header($_[$i], $_[$i + 1]);
	}
	$self;
}

sub add_header {
	my ($self, $key, $value) = @_;
	if (exists $self->{$key}) {
		if ('ARRAY' eq ref $self->{$key}) {
			push @{$self->{$key}}, $value;
		} else {
			$self->{$key} = [$self->{$key}, $value];
		}
	} else {
		$self->{$key} = $value;
	}
}

sub set_header {
	my ($self, $key, $value) = @_;
	$self->{$key} = $value;
}

sub remove_header {
	my ($self, $key) = @_;
	delete $self->{$key};
}

sub get_header {
	my ($self, $key) = @_;
	return if not exists $self->{$key};
	$self->{$key};
}

sub get_all_headers {
	my $self = $_[0];
	my $ret  = [
		map {
			my $key = $_;
			!ref($self->{$key}) || 'ARRAY' ne ref($self->{$key})
				? ($key => $self->{$key})
				: (map {$key => $_} @{$self->{$key}})
		} keys %$self
	];
	$ret;
}

package PEF::Front::HTTPHeaders;
our @ISA = qw(PEF::Front::Headers);

sub new {
	"$_[0]"->SUPER::new(@_[1 .. $#_]);
}

sub _canonical {
	(my $h = lc $_[0]) =~ tr/_/-/;
	$h =~ s/\b(\w)/\u$1/g;
	$h;
}

sub add_header {
	my ($self, $key, $value) = @_;
	$self->SUPER::add_header(_canonical($key), $value);
}

sub set_header {
	my ($self, $key, $value) = @_;
	$self->SUPER::set_header(_canonical($key), $value);
}

sub remove_header {
	my ($self, $key) = @_;
	$self->SUPER::remove_header(_canonical($key));
}

sub get_header {
	my ($self, $key) = @_;
	$self->SUPER::get_header(_canonical($key));
}

1;
