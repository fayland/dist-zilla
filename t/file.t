use strict;
use warnings;
use utf8;
use Test::More;
use Test::Fatal;
use Test::FailWarnings -allow_deps => 1;
binmode(Test::More->builder->$_, ":utf8") for qw/output failure_output todo_output/;

use Encode;
use Path::Tiny;

use Dist::Zilla::File::InMemory;
use Dist::Zilla::File::OnDisk;
use Dist::Zilla::File::FromCode;

my %sample = (
  dolmen  => "Olivier Mengué",
  keedi   =>"김도형 - Keedi Kim",
);

my $sample              = join("\n", values %sample);
my $encoded_sample      = encode("UTF-8", $sample);
my $db_sample          = $sample x 2;
my $db_encoded_sample  = $encoded_sample x 2;

sub new_args {
  my (undef, $file, $line) = caller;
  $file = path($file)->relative;
  my %args = (
    name => 'foo.txt',
    added_by => "$file line $line",
    @_
  );
  return [\%args];
}

sub test_mutable_roundtrip {
  my ($obj) = @_;

  ok( $obj->DOES("Dist::Zilla::Role::MutableFile"), "does MutableFile role" );

  # assumes object content starts as $sample
  is( $obj->content, $sample, "get content" );
  is( $obj->encoded_content, $encoded_sample, "get encoded_content" );

  # set content, check content & encoded_content
  ok( $obj->content($db_sample), "set content");
  is( $obj->content, $db_sample, "get content");
  is( $obj->encoded_content, $db_encoded_sample, "get encoded_content");

  # set encoded_content, check encoded_content & content
  ok( $obj->encoded_content($encoded_sample), "set encoded_content");
  is( $obj->encoded_content, $encoded_sample, "get encoded_content");
  is( $obj->content, $sample, "get content");
}

sub test_content_from_bytes {
  my ($obj, $source_re) = @_;
  # assumes object encoded_content is encoded sample
  is( $obj->encoded_content, $encoded_sample, "get encoded_content" );
  my $err = exception { $obj->content };
  like(
    $err,
    qr/can't decode text from 'bytes'/i,
    "get content from bytes should throw error"
  );
  like( $err, $source_re, "error shows encoded_content source" );
}

subtest "OnDisk" => sub {
  my $class = "Dist::Zilla::File::OnDisk";

  subtest "UTF-8 file" => sub {
    my $tempfile = Path::Tiny->tempfile;

    ok( $tempfile->spew_utf8($sample), "create UTF-8 encoded tempfile" );
    my $obj = new_ok( $class, new_args(name => "$tempfile") );
    test_mutable_roundtrip($obj);
  };

  subtest "binary file" => sub {
    my $tempfile = Path::Tiny->tempfile;

    ok( $tempfile->spew_raw($encoded_sample), "create binary tempfile" );
    my $obj = new_ok( $class, new_args(name => "$tempfile") );
    ok( $obj->encoding("bytes"), "set encoding to 'bytes'");
    test_content_from_bytes($obj, qr/encoded_content set by \S+ line \d+/);
  };

};

subtest "InMemory" => sub {
  my $class = "Dist::Zilla::File::InMemory";

  subtest "UTF-8 string" => sub {
    my $obj = new_ok( $class, new_args(content => $sample) );
    test_mutable_roundtrip($obj);
  };

  subtest "binary string" => sub {
    my $obj = new_ok( $class, new_args( encoded_content => $encoded_sample ) );
    ok( $obj->encoding("bytes"), "set encoding to 'bytes'");
    test_content_from_bytes($obj, qr/encoded_content set by \S+ line \d+/);
  };

};

subtest "FromCode" => sub {
  my $class = "Dist::Zilla::File::FromCode";

  subtest "UTF-8 string" => sub {
    my $obj = new_ok( $class, new_args( code => sub { $sample } ));
    is( $obj->content, $sample, "content" );
    is( $obj->encoded_content, $encoded_sample, "encoded_content" );
  };

  subtest "content immutable" => sub {
    my $obj = new_ok( $class, new_args( code => sub { $sample } ));
    like(
      exception { $obj->content($sample) },
      qr/cannot set content/,
      "changing content should throw error"
    );
    like(
      exception { $obj->encoded_content($encoded_sample) },
      qr/cannot set encoded_content/,
      "changing encoded_content should throw error"
    );
  };

  subtest "binary string" => sub {
    my $obj = new_ok(
      $class, new_args( code_return_type => 'bytes', code => sub { $encoded_sample } )
    );
    test_content_from_bytes($obj, qr/bytes from coderef set by \S+ line \d+/);
  };

};

done_testing;