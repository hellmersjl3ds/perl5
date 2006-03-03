BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir 't' if -d 't';
	@INC = ("../lib", "lib/compress");
    }
}

use lib qw(t t/compress);
use strict;
use warnings;

#use Test::More skip_all => "not implemented yet";
use Test::More ;

BEGIN {
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 978 + $extra;

};



use IO::Compress::Gzip     qw($GzipError) ;
use IO::Uncompress::Gunzip qw($GunzipError) ;

sub identify
{
    return 'IO::Compress::Gzip';
}

require "truncate.pl" ;
run();
