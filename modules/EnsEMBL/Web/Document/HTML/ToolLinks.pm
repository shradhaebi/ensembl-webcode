package EnsEMBL::Web::Document::HTML::ToolLinks;

### Generates links to site tools - BLAST, help, login, etc (currently in masthead)

use strict;
use EnsEMBL::Web::Document::HTML;
use CGI qw(escape);

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new( 'logins' => '?' ); }

sub logins    :lvalue { $_[0]{'logins'};   }
sub referer   :lvalue { $_[0]{'referer'};   } ## Needed by CloseCP

sub render   {
  my $self = shift;
  my $species = $ENV{'ENSEMBL_SPECIES'} || 'default';
  my $url = CGI::escape($ENV{'REQUEST_URI'});
  my $html;
## TO DO - once config tab is working, make this the default view
  if ($self->logins) {
    if ($ENV{'ENSEMBL_USER_ID'}) {
      $html .= qq#
      <a href="javascript:control_panel('/Account/Links?_referer=#.$url.qq#')">Control Panel</a> &nbsp;|&nbsp;
      <a href="javascript:control_panel('/Account/Links?_referer=#.$url.qq#')">Account</a> &nbsp;|&nbsp;
      <a href="javascript:control_panel('/Account/Logout?_referer=#.$url.qq#')">Logout</a> &nbsp;|&nbsp;
      #;
    }
    else {
      $html .= qq#
      <a href="javascript:control_panel('/UserData/Upload?_referer=#.$url.qq#')">Control Panel</a> &nbsp;|&nbsp;
      <a href="javascript:control_panel('/Account/Login?_referer=#.$url.qq#')">Login</a> / 
      <a href="javascript:control_panel('/Account/Register?_referer=#.$url.qq#')">Register</a> &nbsp;|&nbsp;
      #;
    }
=pod
    if ($ENV{'ENSEMBL_USER_ID'}) {
      $html .= qq(
      <a href="/Account/Links?_referer=$url" class="modal_link">Control Panel</a> &nbsp;|&nbsp;
      <a href="/Account/Logout?_referer=$url" class="modal_link">Logout</a> &nbsp;|&nbsp;
      );
    }
    else {
      $html .= qq(
      <a href="/UserData/Upload?_referer=$url" class="modal_link">Control Panel</a> &nbsp;|&nbsp;
      <a href="/Account/Login?_referer=$url" class="modal_link">Login</a> / 
      <a href="/Account/Register?_referer=$url" class="modal_link">Register</a> &nbsp;|&nbsp;
      );
    }
=cut
  }
  else {
    $html .= qq(
      <a href="/UserData/Upload?_referer=$url" class="modal_link">Control Panel</a> &nbsp;|&nbsp;
    );
  }
  $html .= qq(
      <a href="$species/Blast">BLAST</a> &nbsp;|&nbsp; 
      <a href="$species/Biomart">BioMart</a> &nbsp;|&nbsp;
      <a href="/info/website/help/" id="help"><img src="/i/e-quest_bg.gif" alt="e?" style="vertical-align:middle" />&nbsp;Help</a>);
  $self->print($html);
}

1;

