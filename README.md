# content-store-proxy
Mirroring proxy to enable dual-running of MongoDB &amp; PostgreSQL versions of content-store during migration

It will forward all incoming requests to the given `PRIMARY_UPSTREAM` and `SECONDARY_UPSTREAM` URLs in parallel, and return the primary response. Once both upstream responses have been received, it will log a line comparing the two, e.g.

```
> curl http://localhost:4567/api/content/government/publications/care-act-statutory-guidance/care-and-support-statutory-guidance
...

{"timestamp":"2023-10-05T12:00:56Z","level":"info","method":"GET","path":"/api/content/government/publications/care-act-statutory-guidance/care-and-support-statutory-guidance","query_string":"","stats":{"primary_response":{"status":200,"body_size":1773132,"time":0.095294816},"secondary_response":{"status":200,"body_size":1773132,"time":0.101621268},"first_difference":"N/A","different_keys":"N/A"}}

```

Any errors on the secondary response are ignored and do not interfere with the primary response.

## Detailed Response Comparison and CPU-load

Note: comparing the responses is CPU-intensive, and so must be used with care on highly-contended environments like production. For a given percentage of requests, a full comparison will be run which will populate the `first_difference` and `different_keys` keys. The percentage is controlled by the environment variable `COMPARISON_SAMPLE_PCT`. The default value for this is `0` - to compare, say, one in ten requests you would supply `COMPARISON_SAMPLE_PCT=10`.

The full comparison looks like this:

```
{"timestamp":"2023-10-06T09:50:42Z","level":"warn","method":"GET","path":"/content/foreign-travel-advice","query_string":"","stats":{"primary_response":{"status":200,"body_size":327029,"time":0.180271175},"secondary_response":{"status":200,"body_size":327018,"time":0.132149683},"first_difference":{"position":181900,"context":["vice/czech-","vice/gabon\""]},"different_keys":["links","updated_at"]}}
```

`first_difference` gives the index of the first character which differs between the two responses, and the five characters either side of that position in each response.
`different_keys` gives the names of all top-level keys in the two JSON structures which have different values.



# To run

On your *local host*, run:

```
PRIMARY_UPSTREAM=http://content-store.dev.gov.uk SECONDARY_UPSTREAM=http://content-store-on-postgresql.dev.gov.uk bundle exec rackup config.rb -p4567 
```

This will create a proxy server at http://localhost:4567/ , which will forward all requests to both of the upstream services, and return the primary upstream response.

For instance, given the example upstream URLs above, this request:

```
curl http://localhost:4567/api/content/
```
will forward to  http://content-store.dev.gov.uk/api/content/ (primary) and http://content-store-on-postgresql.dev.gov.uk/api/content/, and return the primary response.
