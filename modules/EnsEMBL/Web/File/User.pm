=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::File::User;

use strict;

use parent qw(EnsEMBL::Web::File);

### Replacement for EnsEMBL::Web::TmpFile::Text, specifically for
### content generated by the user, either uploaded to the website
### or generated deliberately via a tool or export interface

### Path structure: /base_dir/YYYY-MM-DD/user_identifier/XXXXXXXXXXXXXXX_filename.ext

sub new {
### @constructor
  my ($class, %args) = @_;

  $args{'drivers'}  = ['IO']; ## Always write to disk
  $args{'base_dir'} =  $args{'hub'}->species_defs->ENSEMBL_TMP_DIR; 
  $args{'url_root'} = ''; 
  return $class->SUPER::new(%args);
}

### Wrappers around E::W::File::Utils::IO methods

sub preview {
### Get n lines of a file, e.g. for a web preview
### @param Integer - number of lines required (default is 10)
### @return Arrayref (n lines of file)
  my ($self, $limit) = @_;
  my $result = {};

  foreach (@{$self->{'output_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::preview_file';
    my $args = {
                'hub'     => $self->hub,
                'raw'     => 0,
                'limit'   => $limit,
                };

    eval {
      no strict 'refs';
      $result = &$method($self, $args);
    };
    next if $result->{'error'};
  }
  return $result;
}

sub write_line {
### Write (append) a single line to a file
### @param String
### @return Hashref
  my ($self, $line) = @_;

  my $result = {};

  foreach (@{$self->{'output_drivers'}}) {
    my $method = 'EnsEMBL::Web::File::Utils::'.$_.'::append_lines';
    my $args = {
                'hub'     => $self->hub,
                'raw'     => 0,
                'lines'   => [$line],
                };

    eval {
      no strict 'refs';
      $result = &$method($self, $args);
    };
    next if $result->{'error'};
  }
  return $result;
}

1;

