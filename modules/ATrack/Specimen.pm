package ATrack::Specimen;

=head1 NAME

ATrack::Specimen - Assembly Tracking Specimen object

=head1 SYNOPSIS
    my $specimen = ATrack::Specimen->new($atrack, $specimen_id);

    my $id      = $specimen->id();
    my $name    = $specimen->name();
    my $alias   = $specimen->alias();
    my $sex     = $specimen->sex();

=head1 DESCRIPTION

An object describing an specimen, i.e. the entity that a sample is taken from.
Specimen objects are usually attached to a ATrack::Sample by the specimen_id on
the Sample.

=head1 AUTHOR

sm15@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);
use ATrack::Species;
use ATrack::Project;

use base qw(ATrack::Named_obj
            ATrack::Hierarchy_obj);


###############################################################################
# Class methods
###############################################################################

=head2 new

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : specimen id
  Example    : my $specimen = ATrack::Specimen->new($atrack, $id)
  Description: Returns Specimen object by specimen_id
  Returntype : ATrack::Specimen object

=cut

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}


=head2 fields_dispatch

  Arg [1]    : none
  Example    : my $fieldsref = $file->fields_dispatch();
  Description: Returns hashref dispatch table keyed on database field
               Used internally for new and update methods
  Returntype : hashref

=cut

sub fields_dispatch
{
    my $self = shift;
    return {
        specimen_id         => sub { $self->id(@_) },
        species_id          => sub { $self->species_id(@_) },
        lims_id             => sub { $self->lims_id(@_) },
        name                => sub { $self->name(@_) },
        hierarchy_name      => sub { $self->hierarchy_name(@_) },
        supplier_name       => sub { $self->supplier_name(@_) },
        accession_id        => sub { $self->accession_id(@_) },
        sex                 => sub { $self->sex(@_) },
        father_id           => sub { $self->father_id(@_) },
        mother_id           => sub { $self->mother_id(@_) },
    };
}

=head2 new_by_name

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : specimen name
  Example    : my $specimen = ATrack::Specimen->new($atrack, $name)
  Description: Class method. Returns Specimen object by name.  If no such name
               is in the database, returns undef
  Returntype : ATrack::Specimen object

=cut


=head2 create

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : specimen name
  Example    : my $specimen = ATrack::Specimen->create($atrack, $name)
  Description: Class method. Creates new Specimen object in the database.
  Returntype : ATrack::Specimen object

=cut

sub create
{
    my ($self, $atrack, $name) = @_;
    my $hierarchy_name = $name;
    $hierarchy_name =~ s/\W+/_/g;
    return $self->SUPER::create($atrack, name => $name, hierarchy_name => $hierarchy_name);
}


###############################################################################
# Object methods
###############################################################################


=head2 dirty

  Arg [1]    : boolean for dirty status
  Example    : $obj->dirty(1);
  Description: Get/Set for object properties having been altered.
  Returntype : boolean

=cut


=head2 id

  Arg [1]    : id (optional)
  Example    : my $id = $specimen->id();
               $specimen->id('104');
  Description: Get/Set for database ID of a specimen
  Returntype : Internal ID integer

=cut


=head2 hierarchy_name

  Arg [1]    : directory name (optional)
  Example    : my $hname = $specimen->hierarchy_name();
  Description: Get/set specimen hierarchy name.  This is the directory name
               (without path) that the specimen will be named in a file
               hierarchy.
  Returntype : string

=cut


=head2 name

  Arg [1]    : name (optional)
  Example    : my $name = $specimen->name();
               $specimen->name('ilVanAtal1');
  Description: Get/Set for specimen name
  Returntype : string

=cut

=head2 lims_id

  Arg [1]    : lims_id (specimen)
  Example    : my $lims_id = $specimen->lims_id();
               $specimen->lims_id('SAN00000001');
  Description: Get/Set for specimen lims_id.
  Returntype : string

=cut

sub lims_id
{
    my $self = shift;
    return $self->_get_set('lims_id', 'string', @_);
}

=head2 supplier_name

  Arg [1]    : supplier_name (specimen)
  Example    : my $supplier_name = $specimen->supplier_name();
               $specimen->supplier_name('Ox0567');
  Description: Get/Set for specimen supplier_name.
  Returntype : string

=cut

sub supplier_name
{
    my $self = shift;
    return $self->_get_set('supplier_name', 'string', @_);
}


=head2 sex

  Arg [1]    : sex (optional)
  Example    : my $sex = $specimen->sex();
               $specimen->sex('M');
  Description: Get/Set for specimen sex
  Returntype : One of 'M', 'F', 'unknown'

=cut

sub sex
{
    my $self = shift;
    if ($_[0])
    {
        unless ($_[0] eq 'M' or $_[0] eq 'F')
        {
            shift;
            unshift(@_, "unknown");
        }
    }
    return $self->_get_set('sex', 'string', @_);
}


=head2 accession_id

  Arg [1]    : accession_id (optional)
  Example    : my $acc = $study->accession_id();
               $specimen->accession_id('ERS000090');
  Description: Get/Set for specimen accession_id, i.e. id for the accession table
  Returntype : string

=cut

sub accession_id
{
    my $self = shift;
    return $self->_get_set('accession_id', 'number', @_);
}

=head2 species_id

  Arg [1]    : species_id (optional)
  Example    : my $species_id = $specimen->species_id();
               $specimen->species_id(123);
  Description: Get/Set for Specimen internal species_id
  Returntype : integer

=cut

sub species_id
{
    my $self = shift;
    return $self->_get_set('species_id', 'number', @_);
}


=head2 species

  Arg [1]    : species name (optional)
  Arg [1]    : strain name (optional)
  Example    : my $species = $specimen->species();
               $specimen->species('Homo sapiens');
  Description: Get/Set for specimen species.  Lazy-loads species object from
               $self->species_id.  If a species name is supplied, then
               species_id is set to the corresponding species in the database.
               If no such species exists, returns undef. Use add_species to add
               a species in this case.
  Returntype : ATrack::Species object

=cut

sub species
{
    my $self = shift;
    return $self->_get_set_child_object('get_species_by_name_strain', 'ATrack::Species', @_);
}


=head2 add_species

  Arg [1]    : species name
  Example    : my $spp = $specimen->add_species('Homo sapiens');
  Description: create a new species, and if successful, return the object
  Returntype : ATrack::Library object

=cut

sub add_species
{
    my $self = shift;
    return $self->_create_child_object('get_species_by_name_strain', 'ATrack::Species', @_);
}


=head2 get_species_by_name

  Arg [1]    : species_name
  Example    : my $pop = $specimen->get_species_by_name('Homo sapiens');
  Description: Retrieve a ATrack::Species object by name
  Returntype : ATrack::Species object

=cut

sub get_species_by_name_strain
{
    my ($self,$name,$strain) = @_;
    return ATrack::Species->new_by_name_strain($self->{atrack}, $name, $strain);
}

sub father_id
{
    my $self = shift;
    return $self->_get_set('father_id', 'number', @_);
}

sub mother_id
{
    my $self = shift;
    return $self->_get_set('mother_id', 'number', @_);
}

=head2 update

  Arg [1]    : None
  Example    : $specimen->update();
  Description: Update a specimen whose properties you have changed. If
               properties haven't changed (i.e. dirty flag is unset) do nothing.
               Unsets the dirty flag on success.
  Returntype : 1 if successful, otherwise undef.

=cut


=head2 atrack

  Arg [1]    : atrack (optional)
  Example    : my $atrack = $obj->atrack();
               $obj->atrack($atrack);
  Description: Get/Set for atrack object.  NB you probably really shouldn't be
               setting atrack from outside this object unless you know what
               you're doing.
  Returntype : integer

=cut

1;
