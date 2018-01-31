package ATrack::Species;

=head1 NAME

ATrack::Species - Assembly Tracking Species object

=head1 SYNOPSIS
    my $spp = ATrack::Species->new($atrack, $species_id);

    my $id      = $species->id();
    my $name    = $species->name();
    my $taxon   = $species->taxon_id();

=head1 DESCRIPTION

An object describing a species.  Species are usually attached to a
ATrack::Sample by the species_id on the individual.

=head1 AUTHOR

jws@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);

use base qw(ATrack::Named_obj);


###############################################################################
# Class methods
###############################################################################

=head2 new

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : species id
  Example    : my $spp = ATrack::Species->new($atrack, $id)
  Description: Returns Species object by species_id
  Returntype : ATrack::Species object

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
        species_id        => sub { $self->id(@_) },
        name              => sub { $self->name(@_) },
        strain            => sub { $self->strain(@_) },
        taxon_id          => sub { $self->taxon_id(@_) },
        common_name       => sub { $self->common_name(@_) },
        taxon_order       => sub { $self->taxon_order(@_) },
        taxon_family      => sub { $self->taxon_family(@_) },
        genome_size       => sub { $self->genome_size(@_) },
        chromosome_number => sub { $self->chromosome_number(@_) }
    };
}

=head2 new_by_name

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : species name
  Example    : my $spp = ATrack::Species->new($atrack, $name)
  Description: Class method. Returns Species object by name.  If no such name is
               in the database, returns undef
  Returntype : ATrack::Species object

=cut

=head2 new_by_name_strain

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : sample name
  Arg [3]    : strain name (optional)
  Example    : my $sample = ATrack::Sample->new_by_name_strain($atrack, $name, $strain)
  Description: Class method. Returns changed Sample object by name and
               project_id. If no such name is in the database, returns undef
  Returntype : VRTrack::Sample object

=cut

sub new_by_name_strain
{
    my ($class, $atrack, $name, $strain) = @_;
    confess "Need to call with a atrack handle and name" unless ($atrack && $name);
    confess "The interface has changed, expected atrack reference." if $atrack->isa('DBI::db');

    my $dbh = $atrack->{_dbh};
    my $sql = q[SELECT species_id FROM species WHERE name = ?];
    $sql .= qq[ and strain = ?] if $strain;
    my $sth = $dbh->prepare($sql);

    my $id;
    if ($sth->execute($name, $strain ? ($strain) : ()))
    {
        my $data = $sth->fetchrow_hashref;
        unless ($data)
        {
            return undef;
        }
        $id = $data->{'species_id'};
    }
    else
    {
        confess(sprintf('Cannot retrieve species by name %s strain %s: %s', $name, $strain, $DBI::errstr));
    }

    return $class->new($atrack, $id);
}


=head2 new_by_taxon_id

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : taxon id
  Example    : my $spp = ATrack::Species->new_by_taxon_id($atrack, $taxon)
  Description: Class method. Returns Species object by taxon id.  If no such
               taxon id is in the database, returns undef
  Returntype : ATrack::Species object

=cut

sub new_by_taxon_id
{
    my ($class, $atrack, $value) = @_;
    return $class->new_by_field_value($atrack, 'taxon_id', $value);
}

=head2 create

  Arg [1]    : database handle to seqtracking database
  Arg [2]    : species name
  Arg [3]    : taxon_id (optional)
  Arg [4]    : strain name (optional)
  Example    : my $spp = ATrack::Species->create($atrack, $name)
  Description: Class method. Creates new Species object in the database.
  Returntype : ATrack::Species object

=cut

sub create
{
    my ($self, $atrack, $name, $strain) = @_;
    return $self->SUPER::create(
        $atrack, name => $name,
        $strain ? (strain => $strain) : ()
    );
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
  Example    : my $id = $spp->id();
               $spp->id('104');
  Description: Get/Set for database ID of a species
  Returntype : Internal ID integer

=cut


=head2 name

  Arg [1]    : name (optional)
  Example    : my $name = $spp->name();
               $spp->name('Homo sapiens');
  Description: Get/Set for species name
  Returntype : string

=cut


=head2 taxon_id

  Arg [1]    : taxon_id (optional)
  Example    : my $taxon_id = $spp->taxon_id();
               $spp->taxon_id(1054);
  Description: Get/Set for species taxon id
  Returntype : integer

=cut

sub taxon_id
{
    my $self = shift;
    return $self->_get_set('taxon_id', 'number', @_);
}

=head2 strain

  Arg [1]    : strain (optional)
  Example    : my $strain = $spp->strain();
               $spp->strain("AB");
  Description: Get/Set for species strain
  Returntype : integer

=cut

sub strain
{
    my $self = shift;
    return $self->_get_set('strain', 'string', @_);
}

sub common_name
{
    my $self = shift;
    return $self->_get_set('common_name', 'string', @_);
}

sub taxon_order
{
    my $self = shift;
    return $self->_get_set('taxon_order', 'string', @_);
}

sub taxon_family
{
    my $self = shift;
    return $self->_get_set('taxon_family', 'string', @_);
}

sub genome_size
{
    my $self = shift;
    return $self->_get_set('genome_size', 'number', @_);
}

sub chromosome_number
{
    my $self = shift;
    return $self->_get_set('chromosome_number', 'number', @_);
}

=head 2 genus

  Example    : my $genus = $species->genus();
  Description: Get the genus name of the species (for now, this is the first
               word)
  Returntype : string

=cut

sub genus
{
    my $self = shift;
    my @whole_name = split(/ /, $self->name());
    return $whole_name[0];
}

=head 2 species_subspecies

  Example    : my $species = $species->species();
  Description: Gets everything after the genus name (for now, these are all the
               words after the first space)
  Returntype : string

=cut

sub species
{
    my $self = shift;
    $self->name() =~ m/(\S+)\s+(.*)/;
    return $2;
}


=head2 update

  Arg [1]    : None
  Example    : $species->update();
  Description: Update a species whose properties you have changed.  If
               properties haven't changed (i.e. dirty flag is unset) do nothing.
               Unsets the dirty flag on success.
  Returntype : 1 if successful, otherwise undef.

=cut

1;
