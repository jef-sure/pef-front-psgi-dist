package PEF::Front::Response;
use strict;
use warnings;
use Time::Duration::Parse;
use Scalar::Util qw(blessed);
use Encode;
use utf8;
use URI::Escape;
use URI;
use PEF::Front::Config;
use PEF::Front::Headers;

sub new {
	my ($class, %args) = @_;
	my $status   = delete $args{status}  || 200;
	my $body     = delete $args{body}    || [];
	my $base_url = delete $args{base}    || '';
	my $href     = delete $args{headers} || [];
	my $cref     = delete $args{cookies} || [];
	my @headers;
	my @cookies;
	if (ref($href) eq 'HASH') {
		@headers = %$href;
	} elsif (ref($href) eq 'ARRAY') {
		@headers = @$href;
	}
	if (ref($cref) eq 'HASH') {
		@cookies = %$cref;
	} elsif (ref($cref) eq 'ARRAY') {
		@cookies = @$cref;
	}
	my $request = delete $args{request};
	if ($request && blessed($request) && $request->isa("PEF::Front::Request")) {
		$base_url ||= $request->base;
		if (not $request->out_headers->is_empty) {
			unshift @headers, $request->out_headers;
		}
		if (not $request->out_cookies->is_empty) {
			unshift @cookies, $request->out_cookies;
		}
	}
	$body = [$body] if not ref $body;
	my $self = bless {
		status   => $status,
		headers  => PEF::Front::HTTPHeaders->new(@headers),
		cookies  => PEF::Front::Headers->new(@cookies),
		body     => $body,
		base_url => $base_url
	}, $class;
	$self;
}

sub add_header {
	my ($self, $key, $value) = @_;
	$self->{headers}->add_header($key, $value);
}

sub set_header {
	my ($self, $key, $value) = @_;
	$self->{headers}->set_header($key, $value);
}

sub remove_header {
	my ($self, $key, $value) = @_;
	$self->{headers}->remove_header($key, $value);
}

sub get_header {
	my ($self, $key) = @_;
	$self->{headers}->get_header($key);
}

sub set_cookie {
	my ($self, $key, $value) = @_;
	$self->{cookies}->set_header($key, $value);
}

sub remove_cookie {
	my ($self, $key) = @_;
	$self->{cookies}->remove_header($key);
}

sub get_cookie {
	my ($self, $key) = @_;
	$self->{cookies}->get_header($key);
}

sub set_body {
	my ($self, $body) = @_;
	$self->{body} = ref($body) ? $body : [$body];
}

sub add_body {
	my ($self, $body) = @_;
	if (ref($self->{body}) eq 'ARRAY') {
		push @{$self->{body}}, $body;
	} else {
		$self->set_body($body);
	}
}

sub get_body {$_[0]->{body}}

sub status {
	my ($self, $status) = @_;
	$self->{status} = $status if defined $status;
	$self->{status};
}

sub redirect {
	my ($self, $url, $status) = @_;
	if ($url) {
		if ($self->{base_url} ne '') {
			my $nuri = URI->new_abs($url, $self->{base_url});
			$url = $nuri->as_string;
		}
		$self->set_header(Location => $url);
		if (!defined $status) {
			$status ||= $self->status;
			$self->status(302) if $status < 300 || $status > 399;
		} else {
			$self->status($status);
		}
		$self->remove_header('Content-Type');
	}
}

sub content_type {
	my ($self, $type) = @_;
	$self->set_header('Content-Type' => $type) if $type;
	return $self->get_header('Content-Type') if defined wantarray;
}

my @dow = qw(Sun Mon Tue Wed Thu Fri Sat);
my @mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

sub expires {
	my $expires = eval {parse_duration($_[0])} || 0;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time + $expires);
	sprintf "%s, %02d-%s-%04d %02d:%02d:%02d GMT", $dow[$wday], $mday, $mon[$mon], 1900 + $year, $hour, $min, $sec;
}

sub safe_encode_utf8 {
	return encode_utf8($_[0]) if not ref($_[0]) && utf8::is_utf8($_[0]);
	$_[0];
}

sub make_headers {
	my ($self) = @_;
	my $headers = $self->{headers}->get_all_headers;
	for (@$headers) {
		$_ = encode_utf8($_) if utf8::is_utf8($_);
	}
	my $cookies = $self->{cookies}->get_all_headers;
	for (my $i = 0; $i < @$cookies; $i += 2) {
		my $name  = safe_encode_utf8($cookies->[$i]);
		my $value = $cookies->[$i + 1];
		$value = '' if not defined $value;
		$value = {value => $value} unless ref($value) eq 'HASH';
		no utf8;
		my @cookie = (URI::Escape::uri_escape($name) . "=" . URI::Escape::uri_escape(safe_encode_utf8($value->{value})));
		push @cookie, "domain=" . $value->{domain}            if $value->{domain};
		push @cookie, "path=" . $value->{path}                if $value->{path};
		push @cookie, "expires=" . expires($value->{expires}) if $value->{expires};
		push @cookie, "max-age=" . $value->{"max-age"}        if $value->{"max-age"};
		push @cookie, "secure"                                if $value->{secure};
		push @cookie, "HttpOnly"                              if $value->{httponly};
		push @$headers, ('Set-Cookie' => join "; ", @cookie);
	}
	return [$self->status, $headers];
}

sub response {
	my ($self) = @_;
	my $out = $self->make_headers;
	if ('ARRAY' eq ref $self->{body}) {
		for (@{$self->{body}}) {
			$_ = encode_utf8($_) if utf8::is_utf8($_);
		}
	}
	push @$out, $self->{body};
	return $out;

}

1;
