package EnsEMBL::Web::Query;

use strict;
use warnings;

use Digest::MD5 qw(md5_base64);
use JSON;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_use);
use Time::HiRes qw(time);

my $DEBUG = 1;

sub _new {
  my ($proto,$store,$impl) = @_;

  my $class = ref($proto) || $proto;
  dynamic_use($impl);
  $impl = $impl->_new($store);
  my $self = { store => $store, impl => $impl };
  bless $self,$class;
  return $self;
}

sub _check_unblessed {
  my ($self,$args) = @_;
  my $ref = ref($args);
  return unless $ref;
  if($ref eq 'ARRAY') {
    $self->_check_unblessed($_) for(@$args);
  } elsif($ref eq 'HASH') {
    $self->_check_unblessed($_) for(values %$args);
  } else {
    die "Cannot pass/return blessed arguments with query: $ref\n";
  }
}

sub _run_phase {
  my ($self,$out,$type,$context,$phase,$extra) = @_;

  $extra ||= [];
  foreach my $k (keys %$type) {
    my $procs = $type->{$k};
    $procs = [$procs] unless ref($procs) eq 'ARRAY';
    foreach my $p (@$procs) {
      $p = [$p] unless ref($p) eq 'ARRAY';
      my @args = @$p;
      my $t = shift @args;
      my $fn = "${phase}_$t";
      if($self->{'impl'}->can($fn)) {
        $self->{'impl'}->$fn($context,$k,$out,@$extra,@args);
      }
    }
  }
  $self->{'impl'}{'_phase'} = $phase;
  $self->{'impl'}{'_data'} = $out;
  $self->{'impl'}{'_context'} = $context;
  $self->{'impl'}{'_args'} = $extra->[0];
  $self->{'impl'}->fixup();
}

sub run_miss {
  my ($self,$args,$type,$sub) = @_;
      
  my %a_gen = %$args;
  $self->_run_phase(\%a_gen,$type,undef,'pre_generate');
  my $part = $self->{'impl'}->$sub(\%a_gen);
  $self->_run_phase($part,$type,undef,'post_generate',[\%a_gen]);
  $self->_check_unblessed($part);
  $self->{'store'}->_set_cache(ref($self),$sub,$args,$part);
  return $part;
}

sub _get {
  my ($self,$type,$context,$sub,$args) = @_;

  my $orig_args = {%$args};
  $args = {%$args};
  use Data::Dumper;
  local $Data::Dumper::Maxdepth = 3;
  my $A = time();
  die "args must be a HASH" unless ref($args) eq 'HASH';
  $self->_run_phase($args,$type,$context,'pre_process');
  my @args = ($args);
  $self->_run_phase(\@args,$type,$context,'split');
  $args = [$args] unless ref($args) eq 'ARRAY';
  my $out = [];
  my $C = time();
  foreach my $a (@args) { 
    warn Dumper('args',$a);
    $self->_check_unblessed($a);
    my $part = $self->{'store'}->_try_get_cache(ref($self),$sub,$a);
    unless(defined $part) {
      $part = $self->run_miss($a,$type,$sub);
    }
    push @$out,@$part;
  }
  my $D = time();
  warn "block gets took ".($D-$C)."s\n" if $DEBUG;
  $self->_run_phase($out,$type,$context,'post_process',[$orig_args]);
  my $E = time();
  warn "post took ".($E-$D)."s\n" if $DEBUG;
  my $B = time();
  warn "get took ".($B-$A)."s\n" if $DEBUG;
  warn "post-process ".scalar(@$out)." features\n";
  return $out;
}

sub source {
  my ($self,$source) = @_;

  return $self->{'store'}->_source($source);
}

sub type {
  my ($self,$sub) = @_;

  (my $type_sub = $sub) =~ s/^get/type/;
  my $type = {};
  if($self->{'impl'}->can($type_sub)) {
    $type = $self->{'impl'}->$type_sub();
  }
  return $type;  
}

sub precache {
  my ($self,$sub,$kind) = @_;

  my $fn = "precache_$sub";
  my $conf = $self->{'impl'}->$fn()->{$kind};
  $fn = "loop_$conf->{'loop'}";
  my $parts = $self->{'impl'}->$fn($conf->{'args'});
  my $type = $self->type("get_$sub");
  $self->{'store'}->open();
  my $start = time();
  foreach my $args (@$parts) {
    my @args = ($args);
    $self->_run_phase(\@args,$type,undef,'split');
    foreach my $a (@args) {
      next if defined $self->{'store'}->_try_get_cache(ref($self),"get_$sub",$a);
      warn "  -> ".$a->{'__name'}."\n";
      if(time()-$start > 60) {
        $self->{'store'}->close();
        $self->{'store'}->open();
        $start = time();
      }
      $self->run_miss($a,$type,"get_$sub");
    }
  }
  $self->{'store'}->close();      
}

sub AUTOLOAD {
  our $AUTOLOAD;
  my $sub = $AUTOLOAD;
  return if $sub =~ /::DESTROY$/;
  if($sub =~ s/^.*::go(_(\w+))?$/get$1/) {
    my ($self,$context,$args) = @_;
    unless($self->{'impl'}->can($sub)) {
      die "$sub doesn't exist in $self->{'impl'}\n";
    }
    my $type = $self->type($sub);
    return $self->_get($type,$context,$sub,$args);
  }
  die "Unknown method $sub\n";
}

1;
