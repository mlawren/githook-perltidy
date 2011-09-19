use Test::More;

eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage"
  if $@;

all_pod_coverage_ok(
    {
        coverage_class => 'Pod::Coverage::CountParents',
        trustme        => [qr/^(new|arg_spec|opt_spec|run|BUILD)$/]
    }
);
