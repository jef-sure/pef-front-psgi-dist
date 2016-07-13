package PEF::Front::Route;

use strict;
use warnings;
use Scalar::Util qw(blessed);
use PEF::Front::Config;
use PEF::Front::Request;
use PEF::Front::Response;
use PEF::Front::Ajax;
use PEF::Front::RenderTT;
use PEF::Front::NLS;
use if cfg_handle_static(), 'File::LibMagic';
use Encode;
use URI::Escape;
use Data::Dumper;

my @rewrite;
my $rulepos = 0;
my $nurlpos = 1;
my $flagpos = 2;
my $tranpos = 3;

sub add_route {
	my @params = @_;
	shift @params if @params & 1;
	for (my $i = 0; $i < @params; $i += 2) {
		my ($rule, $rdest) = @params[$i, $i + 1];
		push @rewrite, [$rule, undef, {}, undef];
		my $ri = $#rewrite;
		if (ref($rdest) eq 'ARRAY') {
			$rewrite[$ri][$nurlpos] = $rdest->[0];
			my @flags = split /[, ]+/, $rdest->[1] if @$rdest > 1;
			for my $f (@flags) {
				my ($p, $v) = split /=/, $f, 2;
				$p = uc $p;
				if ($p eq 'RE' && !$v) {
					warn "regexp rule with empty flags value: $rule -> $rdest->[0] / $rdest->[1]";
					next;
				}
				$rewrite[$ri][$flagpos]{$p} = $v;
			}
		} elsif (ref($rdest) && ref($rdest) ne 'CODE') {
			die "bad routing rule at $rule";
		} else {
			$rewrite[$ri][$nurlpos] = $rdest;
		}
		if (ref($rule) eq 'Regexp') {
			if (!ref($rewrite[$ri][$nurlpos])) {
				$rewrite[$ri][$tranpos]
					= eval "sub {my \$request = \$_[0]; my \$url = \$request->path; return \$url if \$url =~ s\"$rule\""
					. $rewrite[$ri][$nurlpos] . "\""
					. (exists($rewrite[$ri][$flagpos]{RE}) ? $rewrite[$ri][$flagpos]{RE} : "")
					. "; return }";
			} else {
				$rewrite[$ri][$tranpos]
					= eval "sub {my \$request = \$_[0]; "
					. "my \@params = \$request->path =~ "
					. (
					exists($rewrite[$ri][$flagpos]{RE})
					? "m\"$rule\"" . $rewrite[$ri][$flagpos]{RE} . ";"
					: "m\"$rule\"; "
					)
					. "return \$rewrite[$ri][$nurlpos]->(\$request, \@params) if \@params;"
					. "return; }";
			}
		} elsif (ref($rule) eq 'CODE') {
			if (not defined($rewrite[$ri][$nurlpos])) {
				$rewrite[$ri][$tranpos] = $rule;
			} elsif (!ref $rewrite[$ri][$nurlpos]) {
				$rewrite[$ri][$tranpos]
					= eval "sub {my \$request = \$_[0]; "
					. "return '$rewrite[$ri][$nurlpos]' if \$rewrite[$ri][$rulepos]->(\$request);"
					. "return; }";
			} else {
				$rewrite[$ri][$tranpos]
					= eval "sub {my \$request = \$_[0]; "
					. "my \@params = \$rewrite[$ri][$rulepos]->(\$request);"
					. "return \$rewrite[$ri][$nurlpos]->(\$request, \@params) if \@params;"
					. "return; }";
			}
		} else {
			if (!ref $rewrite[$ri][$nurlpos]) {
				$rewrite[$ri][$tranpos]
					= eval "sub {my \$request = \$_[0]; "
					. "return '$rewrite[$ri][$nurlpos]' if \$request->path eq '$rule';"
					. "return; }";
			} else {
				$rewrite[$ri][$tranpos]
					= eval "sub {my \$request = \$_[0]; "
					. "return \$rewrite[$ri][$nurlpos]->(\$request) if \$request->path eq '$rule';"
					. "return; }";
			}
		}
	}
}

sub import {
	return if @rewrite;
	my ($class, @params) = @_;
	add_route(@params);
}

sub rewrite_route {
	my $request = $_[0];
	for (my $i = 0; $i < @rewrite; ++$i) {
		my $rewrite_func  = $rewrite[$i][$tranpos];
		my $rewrite_flags = $rewrite[$i][$flagpos];
		if ((my $npi = $rewrite_func->($request))) {
			my $http_response;
			if (ref $npi) {
				$http_response = $npi->[2] if @$npi > 2;
				$rewrite_flags = $npi->[1] if @$npi > 1;
				$npi           = $npi->[0];
				$npi ||= '';
				if ($rewrite_flags and not ref $rewrite_flags) {
					$rewrite_flags = {map {my ($p, $v) = split /=/, $_, 2; (uc($p), $v)} split /[, ]+/, $rewrite_flags};
				}
			}
			if (%$rewrite_flags and exists $rewrite_flags->{R}) {
				$http_response ||= PEF::Front::Response->new(request => $request);
				$http_response->redirect($npi, $rewrite_flags->{R});
			}
			if (   !$http_response
				&& exists($rewrite_flags->{L})
				&& defined($rewrite_flags->{L})
				&& $rewrite_flags->{L} > 0)
			{
				$http_response = PEF::Front::Response->new(request => $request);
				$http_response->status($rewrite_flags->{L});
			}
			return $http_response
				if $http_response
				&& blessed($http_response)
				&& $http_response->isa('PEF::Front::Response');
			$request->path($npi) if defined $npi;
			last if %$rewrite_flags and exists $rewrite_flags->{L};
		}
	}
	return;
}

sub prepare_context {
	my $request = $_[0];
	my $form    = $request->params;
	my $cookies = $request->cookies;
	my $lang;
	my ($src, $method, $params);
	if (cfg_url_contains_lang) {
		($lang, $src, $method, $params) = $request->path =~ m{^/(\w{2})/(app|ajax|submit|get)([^/]+)/?(.*)$};
		if (not defined $lang) {
			my $http_response = PEF::Front::Response->new(request => $request);
			$http_response->redirect(cfg_location_error, 301);
			return $http_response;
		}
	} else {
		($src, $method, $params) = $request->path =~ m{^/(app|ajax|submit|get)([^/]+)/?(.*)$};
		if (not defined $method) {
			my $http_response = PEF::Front::Response->new(request => $request);
			$http_response->redirect(cfg_location_error, 301);
			return $http_response;
		}
		$lang = PEF::Front::NLS::guess_lang($request);
	}
	if (($src eq 'get' || $src eq 'app') && $params ne '') {
		my @params = split /\//, $params;
		my $i = 1;
		for my $pv (@params) {
			my ($p, $v) = split /-/, $pv, 2;
			if (!defined($v)) {
				$v = $p;
				$p = 'cookie';
				if (exists $form->{$p}) {
					$p = "get_param_$i";
					++$i;
				}
			}
			$form->{$p} = $v;
		}
	}
	return PEF::Front::Response->new(request => $request, status => 404) if $method =~ /[\/.\\]/;
	$method =~ s/[[:upper:]]\K([[:upper:]])/ \l$1/g;
	$method =~ s/[[:lower:]]\K([[:upper:]])/ \l$1/g;
	$method = lcfirst $method;
	return {
		ip        => $request->remote_ip,
		lang      => $lang,
		hostname  => $request->hostname,
		path      => $request->path,
		path_info => $request->path_info,
		form      => $form,
		headers   => $request->headers,
		scheme    => $request->scheme,
		cookies   => $cookies,
		method    => $method,
		src       => $src,
		request   => $request,
	};
}

sub www_static_handler {
	my ($request, $http_response) = @_;
	my $path = $request->path;
	$path =~ s|/{2,}|/|g;
	my @path = split /\//, $path;
	my $valid = 1;
	for (my $i = 0; $i < @path; ++$i) {
		if ($path[$i] eq '..') {
			--$i;
			if ($i < 1) {
				$valid = 0;
				cfg_log_level_error && $request->logger->(
					{   level   => "error",
						message => "not allowed path: " . $request->path
					}
				);
				last;
			}
			splice @path, $i, 2;
			--$i;
		}
	}
	my $sfn = cfg_www_static_dir . $request->path;
	if ($valid && -e $sfn && -r $sfn && -f $sfn) {
		use feature 'state';
		state $file_magic = File::LibMagic->new;
		$http_response->status(200);
		$http_response->set_header('content-type',   $file_magic->checktype_filename($sfn));
		$http_response->set_header('content-length', -s $sfn);
		open my $bh, "<", $sfn;
		$http_response->set_body($bh);
	}
}

my %handlers = (
	'/app'    => \&PEF::Front::RenderTT::handler,
	'/ajax'   => \&PEF::Front::Ajax::handler,
	'/get'    => \&PEF::Front::Ajax::handler,
	'/submit' => \&PEF::Front::Ajax::handler,
);

sub process_request {
	my ($request, $parent_context) = @_;
	cfg_log_level_info
		&& $request->logger->({level => "info", message => "serving request: " . $request->path});
	my $http_response = rewrite_route($request);
	return $http_response if $http_response;
	if (cfg_url_contains_lang
		&& (length($request->path) < 4 || substr($request->path, 3, 1) ne '/'))
	{
		my $lang = PEF::Front::NLS::guess_lang($request);
		if ($request->method eq 'GET') {
			$http_response = PEF::Front::Response->new(request => $request);
			$http_response->redirect("/$lang" . $request->request_uri);
			return $http_response->response();
		} else {
			$request->path("/$lang" . $request->path);
		}
	}
	my $lang_offset = (cfg_url_contains_lang) ? 3 : 0;
	my $handler;
	for my $prefix (keys %handlers) {
		if (substr($request->path, $lang_offset, length $prefix) eq $prefix) {
			$handler = $handlers{$prefix};
			last;
		}
	}
	if ($handler) {
		my $context = prepare_context($request);
		if (blessed($context) && $context->isa('PEF::Front::Response')) {
			return $context->response();
		}
		$context->{parent_context} = $parent_context;
		$handler->($request, $context);
	} else {
		$http_response = PEF::Front::Response->new(request => $request, status => 404);
		www_static_handler($request, $http_response) if cfg_handle_static;
		$http_response->response();
	}
}

sub to_app {
	sub {
		process_request(PEF::Front::Request->new($_[0]));
	};
}
1;
