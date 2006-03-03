package IO::Compress::Zip ;

use strict ;
use warnings;
use bytes;

use IO::Compress::Base::Common qw(createSelfTiedObject);
use IO::Compress::RawDeflate;
use IO::Compress::Adapter::Deflate;
use IO::Compress::Adapter::Identity;

require Exporter ;

our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, $ZipError);

$VERSION = '2.000_08';
$ZipError = '';

@ISA = qw(Exporter IO::Compress::RawDeflate);
@EXPORT_OK = qw( $ZipError zip ) ;
%EXPORT_TAGS = %IO::Compress::RawDeflate::DEFLATE_CONSTANTS ;
push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;
Exporter::export_ok_tags('all');


sub new
{
    my $class = shift ;

    my $obj = createSelfTiedObject($class, \$ZipError);    
    $obj->_create(undef, @_);
}

sub zip
{
    my $obj = createSelfTiedObject(undef, \$ZipError);    
    return $obj->_def(@_);
}

sub mkComp
{
    my $self = shift ;
    my $class = shift ;
    my $got = shift ;

    my ($obj, $errstr, $errno) ;

    if (*$self->{ZipData}{Store}) {
        ($obj, $errstr, $errno) = IO::Compress::Adapter::Identity::mkCompObject(
                                                 $got->value('CRC32'),
                                                 $got->value('Adler32'),
                                                 $got->value('Level'),
                                                 $got->value('Strategy')
                                                 );
    }
    else {
        ($obj, $errstr, $errno) = IO::Compress::Adapter::Deflate::mkCompObject(
                                                 $got->value('CRC32'),
                                                 $got->value('Adler32'),
                                                 $got->value('Level'),
                                                 $got->value('Strategy')
                                                 );
    }

    return $self->saveErrorString(undef, $errstr, $errno)
       if ! defined $obj;

    if (! defined *$self->{ZipData}{StartOffset}) {
        *$self->{ZipData}{StartOffset} = *$self->{ZipData}{Offset} = 0;
    }

    return $obj;    
}



sub mkHeader
{
    my $self  = shift;
    my $param = shift ;
    
    my $filename = '';
    $filename = $param->value('Name') || '';

    my $comment = '';
    $comment = $param->value('Comment') || '';

    my $extract = $param->value('OS_Code') << 8 + 20 ;
    my $hdr = '';

    my $time = _unixToDosTime($param->value('Time'));
    *$self->{ZipData}{StartOffset} = *$self->{ZipData}{Offset} ;

    my $strm = *$self->{ZipData}{Stream} ? 8 : 0 ;
    my $method = *$self->{ZipData}{Store} ? 0 : 8 ;

    $hdr .= pack "V", 0x04034b50 ; # signature
    $hdr .= pack 'v', $extract   ; # extract Version & OS
    $hdr .= pack 'v', $strm      ; # general purpose flag (set streaming mode)
    $hdr .= pack 'v', $method    ; # compression method (deflate)
    $hdr .= pack 'V', $time      ; # last mod date/time
    $hdr .= pack 'V', 0          ; # crc32               - 0 when streaming
    $hdr .= pack 'V', 0          ; # compressed length   - 0 when streaming
    $hdr .= pack 'V', 0          ; # uncompressed length - 0 when streaming
    $hdr .= pack 'v', length $filename ; # filename length
    $hdr .= pack 'v', 0          ; # extra length
    
    $hdr .= $filename ;


    my $ctl = '';

    $ctl .= pack "V", 0x02014b50 ; # signature
    $ctl .= pack 'v', $extract   ; # version made by
    $ctl .= pack 'v', $extract   ; # extract Version
    $ctl .= pack 'v', $strm      ; # general purpose flag (streaming mode)
    $ctl .= pack 'v', $method    ; # compression method (deflate)
    $ctl .= pack 'V', $time      ; # last mod date/time
    $ctl .= pack 'V', 0          ; # crc32
    $ctl .= pack 'V', 0          ; # compressed length
    $ctl .= pack 'V', 0          ; # uncompressed length
    $ctl .= pack 'v', length $filename ; # filename length
    $ctl .= pack 'v', 0          ; # extra length
    $ctl .= pack 'v', length $comment ;  # file comment length
    $ctl .= pack 'v', 0          ; # disk number start 
    $ctl .= pack 'v', 0          ; # internal file attributes
    $ctl .= pack 'V', 0          ; # external file attributes
    $ctl .= pack 'V', *$self->{ZipData}{Offset}  ; # offset to local header
    
    $ctl .= $filename ;
    #$ctl .= $extra ;
    $ctl .= $comment ;

    *$self->{ZipData}{Offset} += length $hdr ;

    *$self->{ZipData}{CentralHeader} = $ctl;

    return $hdr;
}

sub mkTrailer
{
    my $self = shift ;

    my $crc32             = *$self->{Compress}->crc32();
    my $compressedBytes   = *$self->{Compress}->compressedBytes();
    my $uncompressedBytes = *$self->{Compress}->uncompressedBytes();

    my $data ;
    $data .= pack "V", $crc32 ;                           # CRC32
    $data .= pack "V", $compressedBytes   ;               # Compressed Size
    $data .= pack "V", $uncompressedBytes;                # Uncompressed Size

    my $hdr = '';

    if (*$self->{ZipData}{Stream}) {
        $hdr  = pack "V", 0x08074b50 ;                       # signature
        $hdr .= $data ;
    }
    else {
        $self->writeAt(*$self->{ZipData}{StartOffset} + 14, $data)
            or return undef;
    }

    my $ctl = *$self->{ZipData}{CentralHeader} ;
    substr($ctl, 16, 12) = $data ;
    #substr($ctl, 16, 4) = pack "V", $crc32 ;             # CRC32
    #substr($ctl, 20, 4) = pack "V", $compressedBytes   ; # Compressed Size
    #substr($ctl, 24, 4) = pack "V", $uncompressedBytes ; # Uncompressed Size

    *$self->{ZipData}{Offset} += length($hdr) + $compressedBytes;
    push @{ *$self->{ZipData}{CentralDir} }, $ctl ;

    return $hdr;
}

sub mkFinalTrailer
{
    my $self = shift ;

    my $comment = '';
    $comment = *$self->{ZipData}{ZipComment} ;

    my $entries = @{ *$self->{ZipData}{CentralDir} };
    my $cd = join '', @{ *$self->{ZipData}{CentralDir} };

    my $ecd = '';
    $ecd .= pack "V", 0x06054b50 ; # signature
    $ecd .= pack 'v', 0          ; # number of disk
    $ecd .= pack 'v', 0          ; # number if disk with central dir
    $ecd .= pack 'v', $entries   ; # entries in central dir on this disk
    $ecd .= pack 'v', $entries   ; # entries in central dir
    $ecd .= pack 'V', length $cd ; # size of central dir
    $ecd .= pack 'V', *$self->{ZipData}{Offset} ; # offset to start central dir
    $ecd .= pack 'v', length $comment ; # zipfile comment length
    $ecd .= $comment;

    return $cd . $ecd ;
}

sub ckParams
{
    my $self = shift ;
    my $got = shift;
    
    $got->value('CRC32' => 1);

    if (! $got->parsed('Time') ) {
        # Modification time defaults to now.
        $got->value('Time' => time) ;
    }

    *$self->{ZipData}{Stream} = $got->value('Stream');
    *$self->{ZipData}{Store} = $got->value('Store');
    *$self->{ZipData}{ZipComment} = $got->value('ZipComment') ;


    return 1 ;
}

#sub newHeader
#{
#    my $self = shift ;
#
#    return $self->mkHeader(*$self->{Got});
#}

sub getExtraParams
{
    my $self = shift ;

    use IO::Compress::Base::Common qw(:Parse);
    use Compress::Raw::Zlib qw(Z_DEFLATED Z_DEFAULT_COMPRESSION Z_DEFAULT_STRATEGY);

    
    return (
            # zlib behaviour
            $self->getZlibParams(),

            'Stream'    => [1, 1, Parse_boolean,   1],
            'Store'     => [0, 1, Parse_boolean,   0],
            
#            # Zip header fields
#           'Minimal'   => [0, 1, Parse_boolean,   0],
            'Comment'   => [0, 1, Parse_any,       ''],
            'ZipComment'=> [0, 1, Parse_any,       ''],
            'Name'      => [0, 1, Parse_any,       ''],
            'Time'      => [0, 1, Parse_any,       undef],
            'OS_Code'   => [0, 1, Parse_unsigned,  $Compress::Raw::Zlib::gzip_os_code],
            
#           'TextFlag'  => [0, 1, Parse_boolean,   0],
#           'ExtraField'=> [0, 1, Parse_string,    ''],
        );
}

sub getInverseClass
{
    return ('IO::Uncompress::Unzip',
                \$IO::Uncompress::Unzip::UnzipError);
}

sub getFileInfo
{
    my $self = shift ;
    my $params = shift;
    my $filename = shift ;

    my $defaultTime = (stat($filename))[9] ;

    $params->value('Name' => $filename)
        if ! $params->parsed('Name') ;

    $params->value('Time' => $defaultTime) 
        if ! $params->parsed('Time') ;
    
    
}

# from Archive::Zip
sub _unixToDosTime    # Archive::Zip::Member
{
	my $time_t = shift;
    # TODO - add something to cope with unix time < 1980 
	my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($time_t);
	my $dt = 0;
	$dt += ( $sec >> 1 );
	$dt += ( $min << 5 );
	$dt += ( $hour << 11 );
	$dt += ( $mday << 16 );
	$dt += ( ( $mon + 1 ) << 21 );
	$dt += ( ( $year - 80 ) << 25 );
	return $dt;
}

1;

__END__

=head1 NAME


IO::Compress::Zip - Perl interface to write zip files/buffers
 

=head1 SYNOPSIS

    use IO::Compress::Zip qw(zip $ZipError) ;


    my $status = zip $input => $output [,OPTS] 
        or die "zip failed: $ZipError\n";

    my $z = new IO::Compress::Zip $output [,OPTS]
        or die "zip failed: $ZipError\n";

    $z->print($string);
    $z->printf($format, $string);
    $z->write($string);
    $z->syswrite($string [, $length, $offset]);
    $z->flush();
    $z->tell();
    $z->eof();
    $z->seek($position, $whence);
    $z->binmode();
    $z->fileno();
    $z->opened();
    $z->autoflush();
    $z->input_line_number();
    $z->newStream( [OPTS] );
    
    $z->deflateParams();
    
    $z->close() ;

    $ZipError ;

    # IO::File mode

    print $z $string;
    printf $z $format, $string;
    tell $z
    eof $z
    seek $z, $position, $whence
    binmode $z
    fileno $z
    close $z ;
    

=head1 DESCRIPTION



B<WARNING -- This is a Beta release>. 

=over 5

=item * DO NOT use in production code.

=item * The documentation is incomplete in places.

=item * Parts of the interface defined here are tentative.

=item * Please report any problems you find.

=back




This module provides a Perl interface that allows writing zip 
compressed data to files or buffer.







Note that this module is not intended to be a replacement for the module
C<Archive::Zip>.
The primary aim of this module is not as an archiver, but to provide
streaming write access to zip file files and buffers.



For reading zip files/buffers, see the companion module 
L<IO::Uncompress::Unzip|IO::Uncompress::Unzip>.


=head1 Functional Interface

A top-level function, C<zip>, is provided to carry out
"one-shot" compression between buffers and/or files. For finer
control over the compression process, see the L</"OO Interface">
section.

    use IO::Compress::Zip qw(zip $ZipError) ;

    zip $input => $output [,OPTS] 
        or die "zip failed: $ZipError\n";



The functional interface needs Perl5.005 or better.


=head2 zip $input => $output [, OPTS]


C<zip> expects at least two parameters, C<$input> and C<$output>.

=head3 The C<$input> parameter

The parameter, C<$input>, is used to define the source of
the uncompressed data. 

It can take one of the following forms:

=over 5

=item A filename

If the C<$input> parameter is a simple scalar, it is assumed to be a
filename. This file will be opened for reading and the input data
will be read from it.

=item A filehandle

If the C<$input> parameter is a filehandle, the input data will be
read from it.
The string '-' can be used as an alias for standard input.

=item A scalar reference 

If C<$input> is a scalar reference, the input data will be read
from C<$$input>.

=item An array reference 

If C<$input> is an array reference, each element in the array must be a
filename.

The input data will be read from each file in turn. 

The complete array will be walked to ensure that it only
contains valid filenames before any data is compressed.



=item An Input FileGlob string

If C<$input> is a string that is delimited by the characters "<" and ">"
C<zip> will assume that it is an I<input fileglob string>. The
input is the list of files that match the fileglob.

If the fileglob does not match any files ...

See L<File::GlobMapper|File::GlobMapper> for more details.


=back

If the C<$input> parameter is any other type, C<undef> will be returned.



In addition, if C<$input> is a simple filename, the default values for
a number of the zip header fields created by this function will 
be sourced from that file -- 

the NAME gzip header field will be populated with
the filename itself, and the MTIME header field will be set to the
modification time of the file.
The intention here is to mirror part of the behaviour of the 
zip executable.

If you do not want to use these defaults they can be overridden by
explicitly setting the C<Name> and C<Time> options or by setting the
C<Minimal> parameter.



=head3 The C<$output> parameter

The parameter C<$output> is used to control the destination of the
compressed data. This parameter can take one of these forms.

=over 5

=item A filename

If the C<$output> parameter is a simple scalar, it is assumed to be a
filename.  This file will be opened for writing and the compressed
data will be written to it.

=item A filehandle

If the C<$output> parameter is a filehandle, the compressed data
will be written to it.
The string '-' can be used as an alias for standard output.


=item A scalar reference 

If C<$output> is a scalar reference, the compressed data will be
stored in C<$$output>.



=item An Array Reference

If C<$output> is an array reference, the compressed data will be
pushed onto the array.

=item An Output FileGlob

If C<$output> is a string that is delimited by the characters "<" and ">"
C<zip> will assume that it is an I<output fileglob string>. The
output is the list of files that match the fileglob.

When C<$output> is an fileglob string, C<$input> must also be a fileglob
string. Anything else is an error.

=back

If the C<$output> parameter is any other type, C<undef> will be returned.



=head2 Notes

When C<$input> maps to multiple files/buffers and C<$output> is a single
file/buffer the compressed input files/buffers will all be stored
in C<$output> as a single compressed stream.



=head2 Optional Parameters

Unless specified below, the optional parameters for C<zip>,
C<OPTS>, are the same as those used with the OO interface defined in the
L</"Constructor Options"> section below.

=over 5

=item AutoClose =E<gt> 0|1

This option applies to any input or output data streams to 
C<zip> that are filehandles.

If C<AutoClose> is specified, and the value is true, it will result in all
input and/or output filehandles being closed once C<zip> has
completed.

This parameter defaults to 0.



=item BinModeIn =E<gt> 0|1

When reading from a file or filehandle, set C<binmode> before reading.

Defaults to 0.





=item -Append =E<gt> 0|1

TODO


=back



=head2 Examples

To read the contents of the file C<file1.txt> and write the compressed
data to the file C<file1.txt.zip>.

    use strict ;
    use warnings ;
    use IO::Compress::Zip qw(zip $ZipError) ;

    my $input = "file1.txt";
    zip $input => "$input.zip"
        or die "zip failed: $ZipError\n";


To read from an existing Perl filehandle, C<$input>, and write the
compressed data to a buffer, C<$buffer>.

    use strict ;
    use warnings ;
    use IO::Compress::Zip qw(zip $ZipError) ;
    use IO::File ;

    my $input = new IO::File "<file1.txt"
        or die "Cannot open 'file1.txt': $!\n" ;
    my $buffer ;
    zip $input => \$buffer 
        or die "zip failed: $ZipError\n";

To compress all files in the directory "/my/home" that match "*.txt"
and store the compressed data in the same directory

    use strict ;
    use warnings ;
    use IO::Compress::Zip qw(zip $ZipError) ;

    zip '</my/home/*.txt>' => '<*.zip>'
        or die "zip failed: $ZipError\n";

and if you want to compress each file one at a time, this will do the trick

    use strict ;
    use warnings ;
    use IO::Compress::Zip qw(zip $ZipError) ;

    for my $input ( glob "/my/home/*.txt" )
    {
        my $output = "$input.zip" ;
        zip $input => $output 
            or die "Error compressing '$input': $ZipError\n";
    }


=head1 OO Interface

=head2 Constructor

The format of the constructor for C<IO::Compress::Zip> is shown below

    my $z = new IO::Compress::Zip $output [,OPTS]
        or die "IO::Compress::Zip failed: $ZipError\n";

It returns an C<IO::Compress::Zip> object on success and undef on failure. 
The variable C<$ZipError> will contain an error message on failure.

If you are running Perl 5.005 or better the object, C<$z>, returned from 
IO::Compress::Zip can be used exactly like an L<IO::File|IO::File> filehandle. 
This means that all normal output file operations can be carried out 
with C<$z>. 
For example, to write to a compressed file/buffer you can use either of 
these forms

    $z->print("hello world\n");
    print $z "hello world\n";

The mandatory parameter C<$output> is used to control the destination
of the compressed data. This parameter can take one of these forms.

=over 5

=item A filename

If the C<$output> parameter is a simple scalar, it is assumed to be a
filename. This file will be opened for writing and the compressed data
will be written to it.

=item A filehandle

If the C<$output> parameter is a filehandle, the compressed data will be
written to it.
The string '-' can be used as an alias for standard output.


=item A scalar reference 

If C<$output> is a scalar reference, the compressed data will be stored
in C<$$output>.

=back

If the C<$output> parameter is any other type, C<IO::Compress::Zip>::new will
return undef.

=head2 Constructor Options

C<OPTS> is any combination of the following options:

=over 5

=item AutoClose =E<gt> 0|1

This option is only valid when the C<$output> parameter is a filehandle. If
specified, and the value is true, it will result in the C<$output> being
closed once either the C<close> method is called or the C<IO::Compress::Zip>
object is destroyed.

This parameter defaults to 0.

=item Append =E<gt> 0|1

Opens C<$output> in append mode. 

The behaviour of this option is dependent on the type of C<$output>.

=over 5

=item * A Buffer

If C<$output> is a buffer and C<Append> is enabled, all compressed data
will be append to the end if C<$output>. Otherwise C<$output> will be
cleared before any data is written to it.

=item * A Filename

If C<$output> is a filename and C<Append> is enabled, the file will be
opened in append mode. Otherwise the contents of the file, if any, will be
truncated before any compressed data is written to it.

=item * A Filehandle

If C<$output> is a filehandle, the file pointer will be positioned to the
end of the file via a call to C<seek> before any compressed data is written
to it.  Otherwise the file pointer will not be moved.

=back

This parameter defaults to 0.






=item -Level 

Defines the compression level used by zlib. The value should either be
a number between 0 and 9 (0 means no compression and 9 is maximum
compression), or one of the symbolic constants defined below.

   Z_NO_COMPRESSION
   Z_BEST_SPEED
   Z_BEST_COMPRESSION
   Z_DEFAULT_COMPRESSION

The default is Z_DEFAULT_COMPRESSION.

Note, these constants are not imported by C<IO::Compress::Zip> by default.

    use IO::Compress::Zip qw(:strategy);
    use IO::Compress::Zip qw(:constants);
    use IO::Compress::Zip qw(:all);

=item -Strategy 

Defines the strategy used to tune the compression. Use one of the symbolic
constants defined below.

   Z_FILTERED
   Z_HUFFMAN_ONLY
   Z_RLE
   Z_FIXED
   Z_DEFAULT_STRATEGY

The default is Z_DEFAULT_STRATEGY.






=item -Strict =E<gt> 0|1



This is a placeholder option.



=back

=head2 Examples

TODO

=head1 Methods 

=head2 print

Usage is

    $z->print($data)
    print $z $data

Compresses and outputs the contents of the C<$data> parameter. This
has the same behaviour as the C<print> built-in.

Returns true if successful.

=head2 printf

Usage is

    $z->printf($format, $data)
    printf $z $format, $data

Compresses and outputs the contents of the C<$data> parameter.

Returns true if successful.

=head2 syswrite

Usage is

    $z->syswrite $data
    $z->syswrite $data, $length
    $z->syswrite $data, $length, $offset

Compresses and outputs the contents of the C<$data> parameter.

Returns the number of uncompressed bytes written, or C<undef> if
unsuccessful.

=head2 write

Usage is

    $z->write $data
    $z->write $data, $length
    $z->write $data, $length, $offset

Compresses and outputs the contents of the C<$data> parameter.

Returns the number of uncompressed bytes written, or C<undef> if
unsuccessful.

=head2 flush

Usage is


    $z->flush;
    $z->flush($flush_type);


Flushes any pending compressed data to the output file/buffer.


This method takes an optional parameter, C<$flush_type>, that controls
how the flushing will be carried out. By default the C<$flush_type>
used is C<Z_FINISH>. Other valid values for C<$flush_type> are
C<Z_NO_FLUSH>, C<Z_SYNC_FLUSH>, C<Z_FULL_FLUSH> and C<Z_BLOCK>. It is
strongly recommended that you only set the C<flush_type> parameter if
you fully understand the implications of what it does - overuse of C<flush>
can seriously degrade the level of compression achieved. See the C<zlib>
documentation for details.


Returns true on success.


=head2 tell

Usage is

    $z->tell()
    tell $z

Returns the uncompressed file offset.

=head2 eof

Usage is

    $z->eof();
    eof($z);



Returns true if the C<close> method has been called.



=head2 seek

    $z->seek($position, $whence);
    seek($z, $position, $whence);




Provides a sub-set of the C<seek> functionality, with the restriction
that it is only legal to seek forward in the output file/buffer.
It is a fatal error to attempt to seek backward.

Empty parts of the file/buffer will have NULL (0x00) bytes written to them.



The C<$whence> parameter takes one the usual values, namely SEEK_SET,
SEEK_CUR or SEEK_END.

Returns 1 on success, 0 on failure.

=head2 binmode

Usage is

    $z->binmode
    binmode $z ;

This is a noop provided for completeness.

=head2 opened

    $z->opened()

Returns true if the object currently refers to a opened file/buffer. 

=head2 autoflush

    my $prev = $z->autoflush()
    my $prev = $z->autoflush(EXPR)

If the C<$z> object is associated with a file or a filehandle, this method
returns the current autoflush setting for the underlying filehandle. If
C<EXPR> is present, and is non-zero, it will enable flushing after every
write/print operation.

If C<$z> is associated with a buffer, this method has no effect and always
returns C<undef>.

B<Note> that the special variable C<$|> B<cannot> be used to set or
retrieve the autoflush setting.

=head2 input_line_number

    $z->input_line_number()
    $z->input_line_number(EXPR)


This method always returns C<undef> when compressing. 



=head2 fileno

    $z->fileno()
    fileno($z)

If the C<$z> object is associated with a file or a filehandle, this method
will return the underlying file descriptor.

If the C<$z> object is is associated with a buffer, this method will
return undef.

=head2 close

    $z->close() ;
    close $z ;



Flushes any pending compressed data and then closes the output file/buffer. 



For most versions of Perl this method will be automatically invoked if
the IO::Compress::Zip object is destroyed (either explicitly or by the
variable with the reference to the object going out of scope). The
exceptions are Perl versions 5.005 through 5.00504 and 5.8.0. In
these cases, the C<close> method will be called automatically, but
not until global destruction of all live objects when the program is
terminating.

Therefore, if you want your scripts to be able to run on all versions
of Perl, you should call C<close> explicitly and not rely on automatic
closing.

Returns true on success, otherwise 0.

If the C<AutoClose> option has been enabled when the IO::Compress::Zip
object was created, and the object is associated with a file, the
underlying file will also be closed.




=head2 newStream([OPTS])

Usage is

    $z->newStream( [OPTS] )

Closes the current compressed data stream and starts a new one.

OPTS consists of the following sub-set of the the options that are
available when creating the C<$z> object,

=over 5



=item * Level



=back


=head2 deflateParams

Usage is

    $z->deflateParams

TODO


=head1 Importing 


A number of symbolic constants are required by some methods in 
C<IO::Compress::Zip>. None are imported by default.



=over 5

=item :all


Imports C<zip>, C<$ZipError> and all symbolic
constants that can be used by C<IO::Compress::Zip>. Same as doing this

    use IO::Compress::Zip qw(zip $ZipError :constants) ;

=item :constants

Import all symbolic constants. Same as doing this

    use IO::Compress::Zip qw(:flush :level :strategy) ;

=item :flush

These symbolic constants are used by the C<flush> method.

    Z_NO_FLUSH
    Z_PARTIAL_FLUSH
    Z_SYNC_FLUSH
    Z_FULL_FLUSH
    Z_FINISH
    Z_BLOCK

=item :level

These symbolic constants are used by the C<Level> option in the constructor.

    Z_NO_COMPRESSION
    Z_BEST_SPEED
    Z_BEST_COMPRESSION
    Z_DEFAULT_COMPRESSION


=item :strategy

These symbolic constants are used by the C<Strategy> option in the constructor.

    Z_FILTERED
    Z_HUFFMAN_ONLY
    Z_RLE
    Z_FIXED
    Z_DEFAULT_STRATEGY
    

=back

For 

=head1 EXAMPLES

TODO






=head1 SEE ALSO

L<Compress::Zlib>, L<IO::Compress::Gzip>, L<IO::Uncompress::Gunzip>, L<IO::Compress::Deflate>, L<IO::Uncompress::Inflate>, L<IO::Compress::RawDeflate>, L<IO::Uncompress::RawInflate>, L<IO::Compress::Bzip2>, L<IO::Uncompress::Bunzip2>, L<IO::Compress::Lzop>, L<IO::Uncompress::UnLzop>, L<IO::Uncompress::AnyInflate>, L<IO::Uncompress::AnyUncompress>

L<Compress::Zlib::FAQ|Compress::Zlib::FAQ>

L<File::GlobMapper|File::GlobMapper>, L<Archive::Zip|Archive::Zip>,
L<Archive::Tar|Archive::Tar>,
L<IO::Zlib|IO::Zlib>


For RFC 1950, 1951 and 1952 see 
F<http://www.faqs.org/rfcs/rfc1950.html>,
F<http://www.faqs.org/rfcs/rfc1951.html> and
F<http://www.faqs.org/rfcs/rfc1952.html>

The I<zlib> compression library was written by Jean-loup Gailly
F<gzip@prep.ai.mit.edu> and Mark Adler F<madler@alumni.caltech.edu>.

The primary site for the I<zlib> compression library is
F<http://www.zlib.org>.

The primary site for gzip is F<http://www.gzip.org>.







=head1 AUTHOR

The I<IO::Compress::Zip> module was written by Paul Marquess,
F<pmqs@cpan.org>. 



=head1 MODIFICATION HISTORY

See the Changes file.

=head1 COPYRIGHT AND LICENSE
 

Copyright (c) 2005-2006 Paul Marquess. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


