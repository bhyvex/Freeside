package FS::cust_bill_pkg_void;
use base qw( FS::TemplateItem_Mixin FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs dbh fields );
use FS::cust_bill_void;
use FS::cust_bill_pkg_detail;
use FS::cust_bill_pkg_display;
use FS::cust_bill_pkg_discount;
use FS::cust_bill_pkg;
use FS::cust_bill_pkg_tax_location;
use FS::cust_bill_pkg_tax_rate_location;
use FS::cust_tax_exempt_pkg;

=head1 NAME

FS::cust_bill_pkg_void - Object methods for cust_bill_pkg_void records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_void;

  $record = new FS::cust_bill_pkg_void \%hash;
  $record = new FS::cust_bill_pkg_void { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_void object represents a voided invoice line item.
FS::cust_bill_pkg_void inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item billpkgnum

primary key

=item invnum

invnum

=item pkgnum

pkgnum

=item pkgpart_override

pkgpart_override

=item setup

setup

=item recur

recur

=item sdate

sdate

=item edate

edate

=item itemdesc

itemdesc

=item itemcomment

itemcomment

=item section

section

=item freq

freq

=item quantity

quantity

=item unitsetup

unitsetup

=item unitrecur

unitrecur

=item hidden

hidden


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_bill_pkg_void'; }

sub detail_table            { 'cust_bill_pkg_detail_void'; }
sub display_table           { 'cust_bill_pkg_display_void'; }
sub discount_table          { 'cust_bill_pkg_discount_void'; }
#sub tax_location_table      { 'cust_bill_pkg_tax_location'; }
#sub tax_rate_location_table { 'cust_bill_pkg_tax_rate_location'; }
#sub tax_exempt_pkg_table    { 'cust_tax_exempt_pkg'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item unvoid 

"Un-void"s this line item: Deletes the voided line item from the database and
adds back a normal line item (and related tables).

=cut

sub unvoid {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_bill_pkg = new FS::cust_bill_pkg ( {
    map { $_ => $self->get($_) } fields('cust_bill_pkg')
  } );
  my $error = $cust_bill_pkg->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $table (qw(
    cust_bill_pkg_detail
    cust_bill_pkg_display
    cust_bill_pkg_discount
    cust_bill_pkg_tax_location
    cust_bill_pkg_tax_rate_location
    cust_tax_exempt_pkg
  )) {

    foreach my $voided (
      qsearch($table.'_void', { billpkgnum=>$self->billpkgnum })
    ) {

      my $class = 'FS::'.$table;
      my $unvoid = $class->new( {
        map { $_ => $voided->get($_) } fields($table)
      });
      my $error = $unvoid->insert || $voided->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

    }

  }

  $error = $self->delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_number('billpkgnum')
    || $self->ut_snumber('pkgnum')
    || $self->ut_number('invnum') #cust_bill or cust_bill_void, if we ever support line item voiding
    || $self->ut_numbern('pkgpart_override')
    || $self->ut_money('setup')
    || $self->ut_money('recur')
    || $self->ut_numbern('sdate')
    || $self->ut_numbern('edate')
    || $self->ut_textn('itemdesc')
    || $self->ut_textn('itemcomment')
    || $self->ut_textn('section')
    || $self->ut_textn('freq')
    || $self->ut_numbern('quantity')
    || $self->ut_moneyn('unitsetup')
    || $self->ut_moneyn('unitrecur')
    || $self->ut_enum('hidden', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_bill

Returns the voided invoice (see L<FS::cust_bill_void>) for this voided line
item.

=cut

sub cust_bill {
  my $self = shift;
  #cust_bill or cust_bill_void, if we ever support line item voiding
  qsearchs( 'cust_bill_void', { 'invnum' => $self->invnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;
