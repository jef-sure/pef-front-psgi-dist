package PEF::Front::Preload;
use strict;
use warnings;
use PEF::Front::Config;
use PEF::Front::Validator;
use PEF::Front::Connector;
use File::Find;
use Data::Dumper;
use Carp;

my %preload_parts = (
	model         => 1,
	db_connect    => 1,
	local_modules => 1,
	in_filters    => 1,
	out_filters   => 1,
);

sub import {
	my ($class, @args) = @_;
	for my $arg (@args) {
		if ($arg =~ s/^no[-_:]//) {
			delete $preload_parts{$arg};
		} else {
			$preload_parts{$arg} = 1;
		}
	}
	for my $part (keys %preload_parts) {
		if ($preload_parts{$part}) {
			eval "preload_$part();";
			croak $@ if $@;
		}
	}
}

sub preload_model {
	opendir my $mdir, cfg_model_dir
	  or croak "can't open model description directory: $!";
	my @methods =
	  map { s/\.yaml$//; s/[[:upper:]]\K([[:upper:]])/ \l$1/g; s/[[:lower:]]\K([[:upper:]])/ \l$1/g; lcfirst }
	  grep { /\.yaml$/ } readdir $mdir;
	closedir $mdir;
	for (@methods) {
		eval { PEF::Front::Validator::load_validation_rules($_); };
		croak "model $_ validation exception: " . Dumper $@ if $@;
	}
}

sub preload_db_connect {
	PEF::Front::Connector::db_connect();
}

sub preload_any_modules {
	my ($mld, $mt) = @_;
	$mld =~ s|/+$||;
	my $skip_len = 1 + length $mld;
	my @modules;
	find(
		sub {
			my $lname = "$File::Find::dir/$_";
			push @modules, map { s|/|::|g; s|\.pm$||; $_ } substr ($lname, $skip_len)
			  if $lname =~ /\.pm$/;
		},
		$mld
	);
	for (@modules) {
		eval "use " . cfg_app_namespace . $mt . "::" . $_ . ";";
		croak $@ if $@;
	}
}

sub preload_local_modules {
	preload_any_modules(cfg_model_local_dir, "Local");
}

sub preload_in_filters {
	preload_any_modules(cfg_in_filter_dir, "InFilter");
}

sub preload_out_filters {
	preload_any_modules(cfg_out_filter_dir, "OutFilter");
}

1;
