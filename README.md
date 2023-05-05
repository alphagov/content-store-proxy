# content-store-proxy
Mirroring proxy to enable dual-running of MongoDB &amp; PostgreSQL versions of content-store during migration

It will forward all incoming requests to the given `PRIMARY_UPSTREAM` and `SECONDARY_UPSTREAM` URLs, and return the primary response. Once both upstream responses have been received, it will log a line comparing the two, e.g.

```
> curl http://localhost:4567/api/content/government/ministers
...

[2023-05-05T14:37:49.086053 #1430397]  INFO -- : stats: {:primary_response=>{:status=>200, :body_size=>3343568, :time=>0.541455142}, :secondary_response=>{:status=>200, :body_size=>532778, :time=>0.128399933}, :first_difference=>{:position=>187, :context=>["4.000+00:00", "4.000Z\",\"lo"]}}

```

in this line, `:context` gives you the 5 characters either side of the first difference detected in the two response bodies. This has always been (so far) a difference in UTC timezone representation between MongoDB and PostgreSQL, but it's there just for info in case anything else comes up.

# To run

On your local host, run:

````
PRIMARY_UPSTREAM=http://content-store.dev.gov.uk SECONDARY_UPSTREAM=http://content-store-on-postgresql.dev.gov.uk bundle exec ruby app.rb
```

This will create a proxy server at http://localhost:4567/ , which will forward all requests to both of the upstream services.