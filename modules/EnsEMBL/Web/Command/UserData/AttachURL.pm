package EnsEMBL::Web::Command::UserData::AttachURL;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Tools::Misc;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $redirect = $object->species_path($object->data_species).'/UserData/';
  my $param = {};

  my $name = $object->param('name');
  unless ($name) {
    my @path = split('/', $object->param('url'));
    $name = $path[-1];
  }

  if (my $url = $object->param('url')) {
    $url = 'http://'.$url unless $url =~ /^http/;

    ## Check file size
    my $feedback = EnsEMBL::Web::Tools::Misc::get_url_filesize($url);
    if ($feedback->{'error'}) {
      $redirect .= 'SelectURL';
      if ($feedback->{'error'} eq 'timeout') {
        $param->{'filter_module'} = 'Data';
        $param->{'filter_code'} = 'no_response';
      }
      elsif ($feedback->{'error'} eq 'mime') {
        $param->{'filter_module'} = 'Data';
        $param->{'filter_code'} = 'invalid_mime_type';
      }
      else {
        ## Set message in session
        $object->get_session->add_data(
          'type'  => 'message',
          'code'  => 'AttachURL',
          'message' => 'Unable to access file. Server response: '.$feedback->{'error'},
          function => '_error'
        );
      }
    }
    elsif (defined($feedback->{'filesize'}) && $feedback->{'filesize'} == 0) {
      $redirect .= 'SelectURL';
      $param->{'filter_module'} = 'Data';
      $param->{'filter_code'} = 'empty';
    }
    else {
      my $data = $object->get_session->add_data(
        type      => 'url',
        url       => $url,
        name      => $name,
        species   => $object->data_species,
        filesize  => $feedback->{'filesize'},
      );
      if ($object->param('save')) {
        $object->move_to_user('type'=>'url', 'code'=>$data->{'code'});
      }
      $redirect .= 'UrlFeedback';
    }
  } else {
    $redirect .= 'SelectURL';
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_url';
  }

  $self->ajax_redirect($redirect, $param); 
}

1;
