# $Id$

package EnsEMBL::Web::Controller::SSI;

use strict;

use Apache2::Const qw(:common :methods :http);

use SiteDefs qw(:APACHE);

use base qw(EnsEMBL::Web::Controller);

sub page_type       { return 'Static';   }
sub renderer_type   { return 'Apache';   }
sub cacheable       { return 1;          }
sub request         { return 'ssi';      }
sub status  :lvalue { $_[0]->{'status'}; }

sub init {
  my $self = shift;
  $self->update_user_history if $self->hub->user;
  $self->status = $self->_init;
}

sub _init {
  my $self = shift;
  my $r    = $self->r;
  
  $self->clear_cached_content;
  
  return OK if $self->get_cached_content('page'); # Page retrieved from cache
  
  unless (-e $r->filename) {
    $r->log->error('File does not exist: ', $r->filename);
    return NOT_FOUND;
  }
  
  unless (-r $r->filename) {
    $r->log->error('File permissions deny server access: ', $r->filename);
    return FORBIDDEN;
  }
  
  my $page = $self->page;
  
  $page->include_navigation(0); 
  $page->initialize;
  $self->render_page;
  
  return OK;
}

sub content {
  my $self = shift;
  
  if (!$self->{'content'}) {
    my $r    = $self->r;
    my @dirs = reverse(split '/', $r->filename); # parse path and get first 'private_n_nn' folder above current page
    my @groups;
    
    foreach my $d (@dirs) {
      # Is this page under a 'private' folder?
      if ($d =~ /^private(_[0-9]+)+/) {
        (my $grouplist = $d) =~ s/private_//;
        @groups = split '_', $grouplist; # groups permitted to access files 
      }
      
      last if @groups;
    }

    # Read html file into memory to parse out SSI directives.
    {
      local($/) = undef;
      open FH, $r->filename;
      $self->{'content'} = <FH>;
      close FH;
    }
    
    $self->{'content'} =~ s/\[\[([A-Z]+)::([^\]]*)\]\]/my $m = "template_$1"; $self->$m($2);/ge;
  }
  
  return $self->{'content'};
}

sub render_page {
  my $self    = shift;
  my $page    = $self->page;
  my $content = $self->content;
  
  if ($content =~ /<!--#set var="decor" value="none"-->/ || $content =~ /^\s?<head>/) {
    $self->r->print($content);
    return $self->status = OK;
  }
  
  $self->SUPER::render_page;
}

sub set_cache_params {
  my $self = shift;
  
  $ENV{'CACHE_TAGS'}{'STATIC'}           = 1;
  $ENV{'CACHE_TAGS'}{$self->{'url_tag'}} = 1;
  
  $ENV{'CACHE_KEY'}  = $ENV{'REQUEST_URI'};
  $ENV{'CACHE_KEY'} .= "::USER[$self->{'user_id'}]" if $self->{'user_id'};
  $ENV{'CACHE_KEY'} .= '::NO_AJAX'                  unless $self->hub->check_ajax;
  $ENV{'CACHE_KEY'} .= '::MAC'                      if $ENV{'HTTP_USER_AGENT'} =~ /Macintosh/;
  $ENV{'CACHE_KEY'} .= "::IE$1"                     if $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d)/;
}

sub template_SPECIESINFO {
  my ($self, $code) = @_;
  return $self->species_defs->get_config(split /:/, $code);
}

sub template_SPECIESDEFS {
  my ($self, $code) = @_;
  return $self->species_defs->$code;
}

sub template_SPECIES {
  my ($self, $code) = @_;
  return $self->hub->species if $code eq 'code';
  return $self->species_defs->DISPLAY_NAME if $code eq 'name';
  return $self->species_defs->SPECIES_RELEASE_VERSION if $code eq 'version';
  return "**$code**";
}

sub template_RELEASE {
  return shift->species_defs->VERSION;
}

sub template_INCLUDE {
  my ($self, $include) = @_;
  my $hub = $self && $self->can('hub') ? $self->hub : undef;
  my $static_server;

  if ($hub) {
    $static_server = $self->static_server;
    $static_server = '' if $static_server eq $hub->species_defs->ENSEMBL_BASE_URL; # must use $hub->species_defs rather than $self->species_defs because this function is called directly by Components
  }

  my $content;
  
  $include =~ s/\{\{([A-Z]+)::([^\}]+)\}\}/my $m = "template_$1"; $self->$m($2);/ge;
  
  foreach my $root (@ENSEMBL_HTDOCS_DIRS) {
    my $filename = "$root/$include";
    
    if (-f $filename && -e $filename) { 
      if (open FH, $filename) {
        local($/) = undef;
        $content = <FH>;
        close FH;
        $content =~ s/src="(\/i(mg)?\/)/src="$static_server$1/g if $static_server;
        return $content;
      }
    }
  }
  
  # using $hub->apache_handle instead of $self->r because this function is also called by Component modules, providing THEIR $self as this $self
  $hub->apache_handle->log->error('Cannot include virtual file: does not exist or permission denied ', $include) if $hub;
  
  return $content;
}

sub template_SCRIPT {
  my $self     = shift;
  my $include  = shift;
  my $function = shift || 'render';
  
  my ($module, $error) = $self->_use($include, $self->hub);
  
  if ($error) {
    warn "Cannot dynamic_use $include: $error";
  } elsif ($module) {
    return $module->$function;  # Object oriented module
  } else {
    return $include->$function; # Non object oriented script
  }
}

sub template_COMPONENT {
  return shift->template_SCRIPT(@_, 'content');
}

sub template_PAGE {
  my ($self, $rel) = @_;
  return $self->species_defs->ENSEMBL_BASE_URL . "/$rel";
}

sub template_LINK {
  my $self = shift;
  my $url  = $self->template_PAGE(@_);
  return qq{<a href="$url">$url</a>}; 
}

1;
