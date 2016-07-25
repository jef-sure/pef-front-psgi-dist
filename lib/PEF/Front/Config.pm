package PEF::Front::Config;
use warnings;
use strict;
use FindBin;
use File::Basename;
use PEF::Front::RPC;
use feature 'state';
our $project_dir;
our $app_conf_dir;
our $app_namespace;

sub normalize_path {
	my $path = $_[0];
	if (not $path) {
		return '.';
	} elsif (substr($path, -1, 1) ne '/') {
		return $path;
	} else {
		return substr($path, 0, -1);
	}
}

my @std_const_params = qw{
	cfg_upload_dir
	cfg_captcha_db
	cfg_captcha_font
	cfg_captcha_image_init
	cfg_captcha_image_class
	cfg_captcha_secret
	cfg_captcha_symbols
	cfg_captcha_expire_sec
	cfg_model_dir
	cfg_cache_file
	cfg_cache_size
	cfg_cache_method_expire
	cfg_cookie_unset_negative_expire
	cfg_www_static_dir
	cfg_www_static_captchas_dir
	cfg_www_static_captchas_path
	cfg_in_filter_dir
	cfg_out_filter_dir
	cfg_db_user
	cfg_db_password
	cfg_db_name
	cfg_db_reconnect_trys
	cfg_model_rpc_admin_port
	cfg_model_rpc_site_port
	cfg_model_rpc_admin_addr
	cfg_model_rpc_site_addr
	cfg_model_local_dir
	cfg_project_dir
	cfg_app_namespace
	cfg_default_lang
	cfg_url_contains_lang
	cfg_template_dir_contains_lang
	cfg_no_multilang_support
	cfg_location_error
	cfg_template_cache
	cfg_no_nls
	cfg_handle_static
	cfg_log_level_info
	cfg_log_level_error
	cfg_log_level_debug
	cfg_session_db_file
	cfg_session_ttl
	cfg_session_request_field
	cfg_oauth_connect_timeout
	cfg_unknown_msgid_db
	cfg_collect_unknown_msgid
};

my @std_var_params = qw{
	cfg_context_post_hook
	cfg_template_dir
	cfg_model_rpc
	cfg_oauth_client_id
	cfg_oauth_client_secret
	cfg_oauth_scopes
	cfg_logger
	cfg_parse_extra_params
};

our %config_export;

sub import {
	my ($modname) = grep {/AppFrontConfig\.pm$/} keys %INC;
	die "no config" if 0 && !$modname;
	$modname = 'fakemodule' if !$modname;
	(undef, $app_conf_dir, undef) = fileparse($INC{$modname} || '', ".pm");
	$app_conf_dir = normalize_path($app_conf_dir);
	$modname =~ s|\.pm||;
	$modname =~ s|/|::|g;
	($app_namespace = $modname) =~ s/::[^:]*$/::/;
	my $mp = __PACKAGE__;
	my $cp = caller;
	no strict 'refs';
	my @pa = (\@std_const_params, \@std_var_params);

	for (my $i = 0; $i < @pa; ++$i) {
		for my $method (@{$pa[$i]}) {
			(my $bmn = $method) =~ s/^cfg_//;
			my $cref = "$modname"->can($method) || *{$mp . "::std_$bmn"};
			*{$mp . "::$method"}      = $cref;
			*{$cp . "::$method"}      = *{$mp . "::$method"};
			*{$modname . "::$method"} = $cref if not "$modname"->can($method);
			$config_export{$method} = $cref if $i == 0;
		}
	}
	my $exports = \@{$modname . "::EXPORT"};
	for my $e (@$exports) {
		if ((my $cref = "$modname"->can($e))) {
			*{$cp . "::$e"} = $cref;
			$config_export{$e} = $cref;
		}
	}
	if ("$modname"->can("project_dir")) {
		$project_dir = normalize_path("$modname"->project_dir);
	} else {
		my $lpath = $FindBin::Bin;
		$lpath =~ s'(/app$|/conf$|/bin$)'';
		$project_dir = $lpath;
	}
}

sub std_project_dir                  {$project_dir}
sub std_no_nls                       {0}
sub std_unknown_msgid_db             {cfg_project_dir() . "/var/cache/unknown-msgid.db"}
sub std_collect_unknown_msgid        {0}
sub std_model_rpc_admin_port         {5500}
sub std_model_rpc_site_port          {4500}
sub std_model_rpc_admin_addr         {'172.16.0.1'}
sub std_model_rpc_site_addr          {'172.16.0.1'}
sub std_template_cache               {cfg_project_dir() . "/var/tt_cache"}
sub std_location_error               {"/appError?msgid=Internal\%20Error"}
sub std_db_reconnect_trys            {30}
sub std_no_multilang_support         {1}
sub std_default_lang                 {'en'}
sub std_url_contains_lang            {0}
sub std_template_dir_contains_lang   {0}
sub std_handle_static                {0}
sub std_app_namespace                {$app_namespace}
sub std_in_filter_dir                {"$app_conf_dir/InFilter"}
sub std_model_local_dir              {"$app_conf_dir/Local"}
sub std_out_filter_dir               {"$app_conf_dir/OutFilter"}
sub std_upload_dir                   {cfg_project_dir() . "/var/upload"}
sub std_captcha_db                   {cfg_project_dir() . "/var/captcha-db"}
sub std_captcha_font                 {"giant"}
sub std_captcha_image_init           {{}}
sub std_captcha_image_class          {"PEF::Front::SecureCaptcha"}
sub std_captcha_secret               {$app_namespace}
sub std_captcha_expire_sec           {300}
sub std_cache_file                   {cfg_project_dir() . "/var/cache/shared.cache"}
sub std_cache_size                   {"8m"}
sub std_cache_method_expire          {60}
sub std_model_dir                    {cfg_project_dir() . "/model"}
sub std_www_static_dir               {cfg_project_dir() . "/www-static"}
sub std_www_static_captchas_dir      {cfg_project_dir() . "/www-static/captchas"}
sub std_db_user                      {"pef"}
sub std_db_password                  {"pef-pass"}
sub std_db_name                      {"pef"}
sub std_log_level_info               {1}
sub std_log_level_error              {1}
sub std_log_level_debug              {0}
sub std_session_db_file              {cfg_project_dir() . "/var/cache/session.db"}
sub std_session_ttl                  {86400 * 30}
sub std_session_request_field        {'auth'}
sub std_cookie_unset_negative_expire {-3600}
sub std_oauth_connect_timeout        {15}

sub std_captcha_symbols {
	state $symbols = ["0" .. "9", split //, "abCdEFgHiJKLMNOPqRSTUVWXyZ"];
	$symbols;
}

sub std_www_static_captchas_path {
	if (substr(cfg_www_static_captchas_dir(), 0, length(cfg_www_static_dir())) eq cfg_www_static_dir()) {
		# removes cfg_www_static_dir() from cfg_www_static_captchas_dir() and adds '/'
		substr(cfg_www_static_captchas_dir(), length(cfg_www_static_dir())) . '/';
	} else {
		#must be overriden by user
		'/captchas/';
	}
}

sub std_context_post_hook { }

sub std_template_dir {
	cfg_template_dir_contains_lang()
		? cfg_project_dir() . "/templates/$_[1]"
		: cfg_project_dir() . "/templates";
}

sub std_model_rpc {
	if ($_[0] eq 'admin' || $_[0] eq 'rpc_admin') {
		return PEF::Front::RPC->new(
			'Addr' => cfg_model_rpc_admin_addr(),
			'Port' => cfg_model_rpc_admin_port(),
		);
	} else {
		return PEF::Front::RPC->new(
			'Addr' => cfg_model_rpc_site_addr(),
			'Port' => cfg_model_rpc_site_port(),
		);
	}
}

sub std_oauth_client_id {
	state $ids = {
		yandex     => 'anonymous',
		google     => 'anonymous',
		facebook   => 'anonymous',
		v_kontakte => 'anonymous',
		git_hub    => 'anonymous',
	};
	$ids->{$_[0]};
}

sub std_oauth_client_secret {
	state $secrets = {
		yandex     => 'anonymous_secret',
		google     => 'anonymous_secret',
		facebook   => 'anonymous_secret',
		v_kontakte => 'anonymous_secret',
		git_hub    => 'anonymous_secret',
	};
	$secrets->{$_[0]};
}

sub std_oauth_scopes {
	state $scopes = {
		yandex     => {user_info => undef},
		v_kontakte => {user_info => undef},
		git_hub    => {user_info => 'user'},
		google     => {
			email     => 'https://www.googleapis.com/auth/userinfo.email',
			share     => 'https://www.googleapis.com/auth/plus.stream.write',
			user_info => 'https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile'
		},
		facebook => {
			email     => 'email',
			share     => 'publish_actions',
			user_info => 'email',
			offline   => 'offline_access'
		},
		v_kontakte => {user_info => undef},
		git_hub    => {user_info => 'user'},
		msn        => {
			email     => 'wl.emails',
			offline   => 'wl.offline_access',
			share     => 'wl.share',
			user_info => 'wl.basic wl.emails',
		},
		paypal => {
			email     => 'email',
			user_info => 'email profile phone address',
			all       => 'email openid profile phone address'
				. 'https://uri.paypal.com/services/paypalattributes'
				. ' https://uri.paypal.com/services/expresscheckout',
		},
		linked_in => {
			email     => 'r_emailaddress',
			share     => 'rw_nus',
			user_info => 'r_emailaddress r_fullprofile',
			}

	};
	$scopes->{$_[0]};
}

sub std_logger {
	my $request = $_[0];
	$request->{env}{'psgix.logger'}
		|| sub {$request->{env}{'psgi.errors'}->print($_[0]->{message});}
}

sub std_parse_extra_params {
	my ($src, $params, $form) = @_;

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
}


sub cfg {
	my $key     = $_[0];
	my $cfg_key = "cfg_" . $key;
	if (exists $config_export{$cfg_key}) {
		$config_export{$cfg_key}->();
	} elsif (exists $config_export{$key}) {
		$config_export{$key}->();
	} else {
		warn "Unknown config key: $key";
		undef;
	}
}

1;
