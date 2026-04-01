Study https://pgenie.io/ and its documentation.

Study the design project as an example of a java project that we want to be generated (it's distributed in the following repository https://github.com/pgenie-io/java.gen-design/). Study the demo project which should contain the source sql migrations and queries for it (https://github.com/pgenie-io/demo) (it's close, but not an ideal match). Study [the codec Java library](https://github.com/codemine-io/postgresql-codecs.java/), which the example project uses. Study the generator [sdk project](https://github.com/pgenie-io/gen-sdk) (in particular its Dhall SDK https://github.com/pgenie-io/gen-sdk/tree/master/dhall). Study the already working generators for [Haskell](https://github.com/pgenie-io/haskell.gen/) and [Rust](https://github.com/pgenie-io/rust.gen/).

The generator should follow the structure presented in the `java.gen-design` repo (carefully study it).

Carefully study our PostgreSQL codec library https://github.com/codemine-io/postgresql-codecs.java. Use it to derive how mapping should be done.

Handle the unsupported types in the generator by producing warnings and skipping the generation of statements that use them. Do the same for the composite types that use unsupported types in their fields and skip the statements that use them as well. 
