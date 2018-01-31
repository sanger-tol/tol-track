package ATrack::Project;

=head1 NAME

ATrack::Project - Assembly Tracking Project object

=head1 SYNOPSIS
    my $proj = ATrack::Project->new($atrack, $project_id);

    #get arrayref of sample objects in a project
    my $samples = $project->samples();

    my $id = $project->id();
    my $name = $project->name();

=head1 DESCRIPTION

An object describing the tracked properties of a project.

=head1 AUTHOR

sm15@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);
use ATrack::Sample;

use base qw(ATrack::Core_obj
            ATrack::Hierarchy_obj
            ATrack::Named_obj);


=head2 fields_dispatch

  Arg [1]    : none
  Example    : my $fieldsref = $proj->fields_dispatch();
  Description: Returns hashref dispatch table keyed on database field
               Used internally for new and update methods
  Returntype : hashref

=cut

sub fields_dispatch
{
    my $self = shift;

    my %fields = %{$self->SUPER::fields_dispatch()};
    %fields = (
        %fields,
        project_id        => sub { $self->id(@_)},
        lims_id           => sub { $self->lims_id(@_)},
        hierarchy_name    => sub { $self->hierarchy_name(@_)},
        accession         => sub { $self->accession(@_)},
        name              => sub { $self->name(@_)}
    );

    return \%fields;
}

###############################################################################
# Class methods
###############################################################################


=head2 new_by_name

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : project name
  Example    : my $project = ATrack::Project->new_by_name($atrack, $name);
  Description: Class method. Returns current Project object by name and
               project_id.  If no such name is in the database, returns undef
  Returntype : ATrack::Project object

=cut


=head2 new_by_hierarchy_name

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : project hierarchy_name
  Example    : my $project = ATrack::Project->new_by_hierarchy_name($atrack, $hierarchy_name)
  Description: Class method. Returns current Project object by hierarchy_name. If
               no such hierarchy_name is in the database, returns undef.  Dies
               if multiple hierarchy_names match.
  Returntype : ATrack::Project object

=cut


=head2 new_by_ssid

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : project sequencescape id
  Example    : my $project = ATrack::Project->new_by_ssid($atrack, $ssid);
  Description: Class method. Returns current Project object by ssid.  If no such
               lims_id is in the database, returns undef
  Returntype : ATrack::Project object

=cut


=head2 create

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : name
  Example    : my $file = ATrack::Project->create($atrack, $name)
  Description: Class method.  Creates new Project object in the database.
  Returntype : ATrack::Project object

=cut


=head2 is_name_in_database

  Arg [1]    : project name
  Arg [2]    : hierarchy name
  Example    : if(ATrack::Project->is_name_in_database($atrack, $name, $hname)
  Description: Class method. Checks to see if a name or hierarchy name is
               already used in the project table.
  Returntype : boolean

=cut


###############################################################################
# Object methods
###############################################################################

=head2 id

  Arg [1]    : id (optional)
  Example    : my $id = $proj->id();
               $proj->id('104');
  Description: Get/Set for ID of a project
  Returntype : Internal ID integer

=cut


=head2 hierarchy_name

  Arg [1]    : directory name (optional)
  Example    : my $hname = $project->hierarchy_name();
  Description: Get/set project hierarchy name.  This is the directory name
               (without path) that the project will be named in a file
               hierarchy.
  Returntype : string

=cut


=head2 name

  Arg [1]    : name (optional)
  Example    : my $name = $proj->name();
               $proj->name('1000Genomes-B1-TOS');
  Description: Get/Set for project name
  Returntype : string

=cut


=head2 ssid

  Arg [1]    : ssid (optional)
  Example    : my $ssid = $proj->ssid();
               $proj->ssid(104);
  Description: Get/Set for project SequenceScape ID
  Returntype : string

=cut


=head2 changed

  Arg [1]    : changed (optional)
  Example    : my $changed = $project->changed();
               $project->changed('20080810123000');
  Description: Get/Set for project changed
  Returntype : string

=cut


=head2 samples

  Arg [1]    : None
  Example    : my $samples = $project->samples();
  Description: Returns a ref to an array of the sample objects that are
               associated with this project
  Returntype : ref to array of ATrack::Sample objects

=cut

sub samples
{
    my $self = shift;
    return $self->_get_child_objects('ATrack::Sample');
}


=head2 sample_ids

  Arg [1]    : None
  Example    : my $sample_ids = $project->sample_ids();
  Description: Returns a ref to an array of the sample IDs that are associated
               with this project
  Returntype : ref to array of integer sample IDs

=cut

sub sample_ids
{
    my $self = shift;
    return $self->_get_child_ids('ATrack::Sample');
}


=head2 add_sample

  Arg [1]    : sample name
  Example    : my $newproj = $track->add_sample('NOD mouse 1');
  Description: create a new sample, and if successful, return the object
  Returntype : ATrack::Sample object

=cut

sub add_sample
{
    my ($self, $sname) = @_;
    # TODO: if ssid is defined, then it should also not be added twice
    return $self->_add_child_object('new_by_name_project', 'ATrack::Sample', $sname, $self->id);
}


=head2 get_sample_by_name

  Arg [1]    : sample name
  Example    : my $sample = $track->get_sample_by_name('My sample');
  Description: retrieve sample object by name
  Returntype : ATrack::Sample object

=cut

sub get_sample_by_name
{
    my $self = shift;
    return $self->_get_child_by_field_value('samples', 'name', @_);
}


=head2 get_sample_by_id

  Arg [1]    : sample id
  Example    : my $sample = $proj->get_sample_by_id(1154);
  Description: retrieve sample object by internal id
  Returntype : ATrack::Sample object

=cut

sub get_sample_by_id
{
    my $self = shift;
    return $self->_get_child_by_field_value('samples', 'id', @_);
}


=head2 get_sample_by_lims_id

  Arg [1]    : sample LIMS id
  Example    : my $sample = $proj->get_sample_by_lims_id(1154);
  Description: retrieve sample object by sequencescape id
  Returntype : ATrack::Sample object

=cut

sub get_sample_by_lims_id
{
    my $self = shift;
    return $self->_get_child_by_field_value('samples', 'lims_id', @_);
}


=head2 project_id

  Arg [1]    : project_id (optional)
  Example    : my $project_id = $proj->project_id();
               $proj->project_id(1);
  Description: Get/Set for project internal project_id
  Returntype : integer

=cut

sub project_id
{
    my $self = shift;
    return $self->_get_set('project_id', 'number', @_);
}


=head2 project

  Arg [1]    : project accession (optional)
  Example    : my $project = $proj->project();
               $proj->project('SRP000031');
  Description: Get/Set for project project.  Lazy-loads project object from
               $self->project_id.  If a project accession is supplied, then
               project_id is set to the corresponding project in the database.
               If no such project exists, returns undef.  Use add_project to add
               a project in this case.
  Returntype : ATrack::Project object

=cut

sub project
{
    my $self = shift;
    return $self->_get_set_child_object('get_project_by_accession', 'ATrack::Project', @_);
}


=head2 add_project

  Arg [1]    : project acc
  Example    : my $ind = $proj->add_project('NA19820');
  Description: create a new project, and if successful, return the object
  Returntype : ATrack::Project object

=cut

sub add_project
    my $self = shift;
    return $self->_create_child_object('get_project_by_accession', 'ATrack::Project', @_);
}


=head2 get_project_by_accession

  Arg [1]    : study_name
  Example    : my $ind = $proj->get_project_by_accession('NA19820');
  Description: Retrieve a ATrack::Project object by name
  Returntype : ATrack::Study object

=cut

sub get_project_by_accession
{
    my ($self, $acc) = @_;
    return ATrack::Project->new_by_accession$self->{atrack}, $acc);
}


=head2 descendants

  Arg [1]    : none
  Example    : my $desc_objs = $obj->descendants();
  Description: Returns a ref to an array of all objects that are descendants of this object
  Returntype : arrayref of objects

=cut

sub _get_child_methods {
    return qw(samples);
}

1;
