package ATrack::Run;

=head1 NAME

ATrack::Run - Assembly Tracking Run object

=head1 SYNOPSIS
    my $run= ATrack::Run->new($atrack, $seq_id);

    my $id = $run->id();
    my $qc_status = $run->qc_status();

=head1 DESCRIPTION

An object describing the tracked properties of a Run object.

=head1 AUTHOR

sm15@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);
use ATrack::File;
use File::Spec;

use base qw(ATrack::Core_obj
            ATrack::Hierarchy_obj
            ATrack::Named_obj);


=head2 fields_dispatch

  Arg [1]    : none
  Example    : my $fieldsref = $seq->fields_dispatch();
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
        run_id             => sub { $self->id(@_)},
        name               => sub { $self->name(@_)},
        hierarchy_name     => sub { $self->hierarchy_name(@_)},
        lims_id            => sub { $self->lims_id(@_)},
        platform_id        => sub { $self->platform_id(@_)},
        centre_id          => sub { $self->centre_id(@_)},
        run_element        => sub { $self->run_element(@_)},   # e.g. well label for PacBio, lane for Illumina
        lims_qc_status     => sub { $self->lims_qc_status(@_)},
        run_date           => sub { $self->run_date(@_)}
    );

    return \%fields;
}

###############################################################################
# Class methods
###############################################################################

=head2 new_by_name

  Arg [1]    : atrack handle
  Arg [2]    : seq name
  Example    : my $seq = ATrack::Seq->new_by_name($atrack, $name)
  Description: Class method. Returns current Seq object by name.  If no such name is in the database, returns undef.  Dies if multiple names match.
  Returntype : ATrack::Seq object

=cut


=head2 new_by_hierarchy_name

  Arg [1]    : atrack handle
  Arg [2]    : seq hierarchy_name
  Example    : my $seq = ATrack::Seq->new_by_hierarchy_name($atrack, $hierarchy_name)
  Description: Class method. Returns current Seq object by hierarchy_name.  If no such hierarchy_name is in the database, returns undef.  Dies if multiple hierarchy_names match.
  Returntype : ATrack::Seq object

=cut


=head2 is_name_in_database

  Arg [1]    : seq name
  Arg [2]    : hierarchy name
  Example    : if(ATrack::Seq->is_name_in_database($atrack, $name, $hname)
  Description: Class method. Checks to see if a name or hierarchy name is already used in the seq table.
  Returntype : boolean

=cut


=head2 create

  Arg [1]    : atrack handle to assembly tracking database
  Arg [2]    : name
  Example    : my $file = ATrack::Seq->create($atrack, $name)
  Description: Class method.  Creates new Seq object in the database.
  Returntype : ATrack::Seq object

=cut


###############################################################################
# Object methods
###############################################################################

=head2 id

  Arg [1]    : id (optional)
  Example    : my $id = $seq->id();
               $seq->id(104);
  Description: Get/Set for internal db ID of a seq
  Returntype : integer

=cut


=head2 library_id

  Arg [1]    : library_id (optional)
  Example    : my $library_id = $seq->library_id();
               $seq->library_id('104');
  Description: Get/Set for ID of a seq
  Returntype : Internal ID

=cut

sub library_id
{
    my $self = shift;
    return $self->_get_set('library_id', 'number', @_);
}


=head2 hierarchy_name

  Arg [1]    : directory name (optional)
  Example    : my $hname = $seq->hierarchy_name();
  Description: Get/set seq hierarchy name.  This is the directory name (without path) that the seq will be named in a file hierarchy.
  Returntype : string

=cut


=head2 name

  Arg [1]    : name (optional)
  Example    : my $name = $seq->name();
           $seq->name('1044_1');
  Description: Get/Set for name of a seq
  Returntype : string

=cut


=head2 accession

  Arg [1]    : accession (optional)
  Example    : my $accession = $seq->accession();
           $seq->accession('ERR0000538');
  Description: Get/Set for [ES]RA/DCC accession
  Returntype : string

=cut

sub accession
{
    my $self = shift;
    return $self->_get_set('accession', 'string', @_);
}


=head2 is_withdrawn

  Arg [1]    : boolean for is_withdrawn status
  Example    : $seq->is_withdrawn(1);
  Description: Get/Set for whether seq has been withdrawn or not
  Returntype : boolean (undef if withdrawn status had never been set)

=cut

sub is_withdrawn
{
    my $self = shift;
    return $self->_get_set('is_withdrawn', 'boolean', @_);
}


=head2 is_manually_withdrawn

  Arg [1]    : boolean for is_manually_withdrawn status
  Example    : $seq->is_manually_withdrawn(1);
  Description: Get/Set for whether seq has been manually withdrawn or not;
               The distinction between this and is_withdrawn is that a seq that
               is manually withdrawn won't be automatically unwithdrawn by some
               automated system that checks this value.
  Returntype : boolean (undef if withdrawn status had never been set)

=cut

sub is_manually_withdrawn
{
    my $self = shift;
    my $withdrawn = $self->_get_set('is_manually_withdrawn', 'boolean', @_);
    if (defined $withdrawn)
    {
        $self->is_withdrawn($withdrawn);
    }
    return $withdrawn;
}

=head2 auto_qc_status

  Arg [1]    : auto_qc_status (optional)
  Example    : my $qc_status = $seq->auto_qc_status();
           $seq->auto_qc_status('passed');
  Description: Get/Set for seq auto_qc_status
  Returntype : string

=cut

sub auto_qc_status
{
    my $self = shift;
    $self->_check_status_value('auto_qc_status', @_);
    return $self->_get_set('auto_qc_status', 'string', @_);
}


=head2 qc_status

  Arg [1]    : qc_status (optional)
  Example    : my $qc_status = $seq->qc_status();
           $seq->qc_status('passed');
  Description: Get/Set for seq qc_status
  Returntype : string

=cut

sub qc_status
{
    my $self = shift;
    $self->_check_status_value('qc_status', @_);
    return $self->_get_set('qc_status', 'string', @_);
}


=head2 lims_qc_status

  Arg [1]    : lims_qc_status (optional)
  Example    : my $lims_qc_status = $seq->lims_qc_status();
           $seq->lims_qc_status('pass');
  Description: Get/Set for seq lims_qc_status. This is the manual QC from LIMS.
  Returntype : string

=cut

sub lims_qc_status
{
    my $self = shift;
    $self->_check_status_value('lims_qc_status', @_);
    return $self->_get_set('lims_qc_status', 'string', @_);
}

=head2 run_date

  Arg [1]    : run_date (optional)
  Example    : my $run_date = $seq->run_date();
               $seq->run_date('20080810123000');
  Description: Get/Set for seq run_date
  Returntype : string

=cut

sub run_date
{
    my $self = shift;
    return $self->_get_set('run_date', 'string', @_);
}


=head2 changed

  Arg [1]    : changed (optional)
  Example    : my $changed = $seq->changed();
               $seq->changed('20080810123000');
  Description: Get/Set for seq changed
  Returntype : string

=cut


=head2 centre

  Arg [1]    : centre name (optional)
  Example    : my $centre = $library->centre();
               $library->centre('SC');
  Description: Get/Set for sample centre.  Lazy-loads centre object from $self->centre_id.  If a centre name is supplied, then centre_id is set to the corresponding centre in the database.  If no such centre exists, returns undef.  Use add_centre to add a centre in this case.
  Returntype : ATrack::Centre object

=cut

sub centre
{
    my $self = shift;
    return $self->_get_set_child_object('get_centre_by_name', 'ATrack::Centre', @_);
}


=head2 add_centre

  Arg [1]    : centre name
  Example    : my $seq_centre = $library->add_centre('WSI');
  Description: create a new centre, and if successful, return the object
  Returntype : ATrack::Library object

=cut

sub add_centre
{
    my $self = shift;
    return $self->_create_child_object('get_centre_by_name', 'ATrack::Centre', @_);
}


=head2 descendants

  Arg [1]    : none
  Example    : my $desc_objs = $obj->descendants();
  Description: Returns a ref to an array of all objects that are descendants of this object
  Returntype : arrayref of objects

=cut

sub _get_child_methods
{
    return qw(files mappings);
}

1;
