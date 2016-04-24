package PEF::Front::RenderTT;

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(blessed);
use Encode;
use URI::Escape;
use Template::Alloy;
use PEF::Front::Config;
use PEF::Front::Cache;
use PEF::Front::Validator;
use PEF::Front::NLS;
use PEF::Front::Response;
use Sub::Name;

sub handler {
	my ($request, $defaults) = @_;
	my $form          = $request->params;
	my $cookies       = $request->cookies;
	my $logger        = $request->logger;
	my $http_response = PEF::Front::Response->new(request => $request);
	my $lang          = $defaults->{lang};
	$http_response->set_cookie(lang => {value => $lang, path => "/"});
	my $template = delete $defaults->{method};
	$template =~ tr/ /_/;
	my $template_file = "$template.html";
	my $found         = 0;
	for my $tdir ((cfg_template_dir($request, $lang))) {
		my $full_template_file = $tdir . "/" . $template_file;
		if (-f $full_template_file) {
			$found = 1;
			cfg_log_level_info
			  && $logger->({level => "info", message => "found template '$full_template_file'"});
			last;
		}
	}
	if (!$found) {
		cfg_log_level_info
		  && $logger->({level => "info", message => "template '$template' not found"});
		$http_response->status(404);
		return $http_response->response();
	}
	$defaults->{template}  = $template;
	$defaults->{time}      = time;
	$defaults->{gmtime}    = [gmtime];
	$defaults->{localtime} = [localtime];
	my $model = subname model => sub {
		my %req;
		my $method;
		for (@_) {
			if (ref) {
				%req = (%$_, %req);
			} else {
				$method = $_;
			}
		}
		$req{method} = $method if defined $method;
		my $vreq = eval { validate(\%req, $defaults) };
		my $response;
		if (!$@) {
			my $as = get_method_attrs($vreq => 'allowed_source');
			if ($as
				&& (   (!ref ($as) && $as ne 'template')
					|| (ref ($as) eq 'ARRAY' && !grep { $_ eq 'template' } @$as))
			  )
			{
				cfg_log_level_error
				  && $logger->({level => "error", message => "not allowed source"});
				return {
					result      => 'INTERR',
					answer      => 'Unallowed calling source',
					answer_args => []
				};
			}
			my $cache_attr = get_method_attrs($vreq => 'cache');
			my $cache_key;
			if ($cache_attr) {
				$cache_key = make_request_cache_key($vreq, $cache_attr);
				$cache_attr->{expires} = cfg_cache_method_expire unless exists $cache_attr->{expires};
				cfg_log_level_debug && $logger->({level => "debug", message => "cache key: $cache_key"});
				$response = get_cache("ajax:$cache_key");
			}
			if (not $response) {
				my $model = get_model($vreq);
				cfg_log_level_debug
				  && $logger->({level => "debug", message => "model: $model"});
				if (index ($model, "::") >= 0) {
					my $class = substr ($model, 0, rindex ($model, "::"));
					eval "use $class;\n\$response = $model(\$vreq, \$defaults)";
				} else {
					$response = cfg_model_rpc($model)->send_message($vreq)->recv_message;
				}
				if ($@) {
					cfg_log_level_error
					  && $logger->({level => "error", message => "error: " . Dumper($model, $@, $vreq)});
					return {result => 'INTERR', answer => 'Internal error', answer_args => []};
				}
				if ($response->{result} eq 'OK' && $cache_attr) {
					set_cache("ajax:$cache_key", $response, $cache_attr->{expires});
				}
			}
		}
		return $response;
	};
	my $tt = Template::Alloy->new(
		INCLUDE_PATH => [cfg_template_dir($request, $lang)],
		COMPILE_DIR  => cfg_template_cache,
		V2EQUALS     => 0,
		ENCODING     => 'UTF-8',
	);
	$tt->define_vmethod('text', model => $model);
	$tt->define_vmethod('hash', model => $model);
	$tt->define_vmethod(
		'text',
		config => subname(
			config => sub {
				my ($key) = @_;
				PEF::Front::Config::cfg($key);
			}
		)
	);
	$tt->define_vmethod(
		'text',
		m => subname(
			m => sub {
				my ($msgid, @params) = @_;
				msg_get($lang, $msgid, @params)->{message};
			}
		)
	);
	$tt->define_vmethod(
		'text',
		mn => subname(
			mn => sub {
				my ($msgid, $num, @params) = @_;
				msg_get_n($lang, $msgid, $num, @params)->{message};
			}
		)
	);
	$tt->define_vmethod(
		'text',
		ml => subname(
			ml => sub {
				my ($msgid, $tlang, @params) = @_;
				msg_get($tlang, $msgid, @params)->{message};
			}
		)
	);
	$tt->define_vmethod(
		'text',
		mnl => subname(
			mnl => sub {
				my ($msgid, $num, $tlang, @params) = @_;
				msg_get_n($tlang, $msgid, $num, @params)->{message};
			}
		)
	);
	$tt->define_vmethod(
		'text',
		uri_unescape => subname(
			uri_unescape => sub {
				uri_unescape(@_);
			}
		)
	);
	$tt->define_vmethod(
		'text',
		strftime => subname(
			strftime => sub {
				return if ref $_[1] ne 'ARRAY';
				strftime($_[0], @{$_[1]});
			}
		)
	);
	$tt->define_vmethod(
		'text',
		gmtime => subname(
			gmtime => sub {
				return [gmtime ($_[0])];
			}
		)
	);
	$tt->define_vmethod(
		'text',
		localtime => subname(
			localtime => sub {
				return [localtime ($_[0])];
			}
		)
	);
	$tt->define_vmethod(
		'text',
		response_content_type => (
			subname response_content_type => sub {
				$http_response->content_type($_[0]);
				return;
			}
		)
	);
	$tt->define_vmethod(
		'text',
		request_get_header => subname(
			request_get_header => sub {
				return $request->headers->get_header($_[0]);
			}
		)
	);
	$tt->define_vmethod(
		'text',
		response_set_header => subname(
			response_set_header => sub {
				my @p = ref ($_[0]) eq 'HASH' ? %{$_[0]} : @_;
				$http_response->set_header(@p);
				return;
			}
		)
	);
	$tt->define_vmethod(
		'text',
		response_set_cookie => subname(
			response_set_cookie => sub {
				my @p = ref ($_[0]) eq 'HASH' ? %{$_[0]} : @_;
				$http_response->set_cookie(@p);
				return;
			}
		)
	);
	$tt->define_vmethod(
		'text',
		response_set_status => subname(
			response_set_status => sub {
				$http_response->status($_[0]);
				return;
			}
		)
	);
	$tt->define_vmethod(
		'text',
		session => subname(
			session => sub {
				$defaults->{session} ||= PEF::Front::Session->new($request);
				if (@_) {
					return $defaults->{session}->data->{$_[0]};
				} else {
					return $defaults->{session}->data;
				}
			}
		)
	);
	$http_response->content_type('text/html; charset=utf-8');
	$http_response->set_body('');
	return sub {
		my $responder = $_[0];
		$tt->process($template_file, $defaults, \$http_response->get_body->[0])
		  or cfg_log_level_error && $logger->({level => "error", message => "error: " . $tt->error()});
		$responder->($http_response->response());
	};
}

1;
