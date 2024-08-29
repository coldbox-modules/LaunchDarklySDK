# LaunchDarkly CFML SDK

A CFML SDK for LaunchDarkly feature flags

## Requirements

This runs on Lucee 5+ and Adobe CF 2016+.
The SDK is set up as a ColdBox module, however it will also work with WireBox standalone or just a legacy app.

## Installation

Use CommandBox to install it:
```bash
install launchdarklysdk
```

If you're allergic to CLI's, you can snag the code from Github or Forgebox, but it will be up to you to acquire the jar file referenced in the `box.json`.

Since I hate using javaloader in The Year of Our Lord 2021, you must manually add the jars to your `Application.cfc`'s `this.javaSettings`.  This can be done pretty quickly with a little snippet like so (adjust the paths as necessary):
```js
this.javaSettings = {
	loadPaths = directorylist( expandPath( '/modules/LaunchDarklySDK/lib' ), true, 'array', '*jar' ),
	loadColdFusionClassPath = true,
	reloadOnChange = false
};
```

Sometimes, CF needs a restart for this setting to work.  I don't know why, I just know I've seen it happen ¯\_(ツ)_/¯
Note, Adobe Coldfusion **requires** the `loadColdFusionClassPath` to be true.

## Usage

If you're a cool kid and using ColdBox, you can just inject the client class (called `LD`)...

```js
property name="LD" inject="LD@LaunchDarklySDK";
```
and start using it...
```js
if( LD.variation(  featureKey='my-feature-flag', defaultValue=false ) ) {
    // enable awesomeness
}
```
The module will automatically shutdown the client when ColdBox reinits via the unicorn magic of ColdBox interceptors.
Configure the client in a ColdBox setting by adding to your `moduleSettings` struct in `/config/Coldbox.cfc`.  (All config values listed below)

```js
moduleSettings = {
  'LaunchDarklySDK' : {
      SDKKey : 'my-key-here'
  }
};
```

If you're using this library outside of ColdBox, there's a couple things you'll need to do manually.

### Create the client CFC (WireBox standalone)

Map the CFC in Wirebox's binder.  Pass your configuration as a struct to the mapping DSL.  The key names and values are the same as what you'd put in the ColdBox config.  (All config values listed below)

```js
binder
    .mapPath( '/modules/LaunchDarklySDK/models/LD.cfc' )
    .initArg(
        name='settings',
        value={
            SDKKey : 'my-key-here'
        });
```

WireBox will create it as needed and automatically persist it as a singleton.  All you need to do is ask WireBox for it when you need it:

```js
wirebox.getInstance( 'LD' )
```

### Shutdown the client before re-creating it (WireBox standalone)

If you have code that re-creates your application like a framework reinit, you'll want to shutdown the old LD client CFC to release underlying resources before you recreate it again.

```js
wirebox.getInstance( 'LD' ).shutdown();
```

### Create the client CFC (Non-ColdBox/WireBox)

ONLY DO THIS ONCE AND STORE IT AS A SINGLETON.
Pass your configuration as a struct to the constructor.  The key names and values are the same as what you'd put in the ColdBox config.  (All config values listed below)

```js
application.LD = new models.LD( {
	SDKKey:'my-key-here'
});
```

### Shutdown the client before re-creating it (Non-ColdBox/WireBox)

If you have code that re-creates your application like a framework reinit, you'll want to shutdown the old LD client CFC to release underlying resources before you recreate it again.

```js
application.LD.shutdown();
```

## Configuration

Here's a list of the currently-support config items.  These can go in your `/config/Coldbox.cfc` or can be passed as a struct to the `LD` constructor in non-ColdBox mode.

* `SDKKey` - (**Required**) your SDK Key from LaunchDarkly
* `diagnosticOptOut` - Set to true to opt-out of sending diagnostics data.
* `startWaitms` - Set how long in millisecond the constructor will block awaiting a successful connection to LaunchDarkly.
* `offline` - Set whether this client is offline.
* `contextProvider` - A closure that returns a struct of context details for the current logged-in context.  The only required key is "key" which must be unique.
* `registerFlagChangeListener` - This is a generic listener that will be fired any time any data changes on any flag for any context. (more below)
* `registerFlagValueChangeListener()` - This is a very specific listener that will tell you specifically when the flag variation value for a specific context changes. (more below)

```js
{
        SDKKey : 'my-key',
        contextProvider=()=>{
            if( session.keyExists( 'user' ) ) {
                return {
                    'key' : session.user.id,
                    'name' : session.user.fullname,
                    'email' : session.user.email,
                    'country' : session.user.country,
                    'privateAttributes' : ['email']
                };
            } else {
                // Anonymous
                return {};
            }
        }
}
```
Additional Notes:

LaunchDarkly is case-sensitive for the attribute names, so be sure to quote them as shown above if you are on a CF version that will uppercase struct key names, as you otherwise may have issues with targeting based on those custom attributes.

Also, for older versions of Adobe ColdFusion, you'll need to use this closure syntax:
```js
{
        SDKKey : 'my-key',
        contextProvider=function(){
            // Logic here
        }
}
```


## Check feature variations

You can get a variation value like so.  Note, the type of data coming back will depend on what type is set in the feature flag config in the Launchdarkly console.  A default value that matches the feature data type is always required.

```js
if( LD.variation(  'my-feature-flag', false ) ) {
    // enable awesomeness
}
```

You can use the method above for all feature flag types, but there are also methods provided for each type just to match the Java SDK.

```js
if( LD.booleanVariation( 'my-feature', false ) ) {
    // enabled
}

var colWidth = LD.numberVariation( 'homepage-columns', 3 );

var welcomeText = LD.stringVariation( 'homepage-welcome-text', 'Get off my lawn!' );

var shoppingCartConfig = LD.JSONVariation(
    'shopping-cart-config',
    {
        allowCoupons : true,
        experiemntalFeatures : false,
        autoCalcTaxes : true
    } );
```

The `JSONVariation()` method will accept a complex value as the "default" and will also deserialize whatever JSON is stored in the variation so you get back a proper struct or array.

You can get a reason for the current result by calling the "detail" version of each method, which returns a struct containing both the `value` of the variation and the `detail` explanation of why it was chosen.


```js
var results = LD.booleanVariationDetail( 'my-feature', false );
if( results.value ) {
    writeOutput( 'Enabled because of #results.detail#' );
} else {
    writeOutput( 'Disabled because of #results.detail#' );
}
```

## Get all flags for a context

You can get all the flags and their current values for a context like so:

```js
var flagData = LD.getAllFlags()
```
The result will be a struct with an `isValid` key that comes from the underlying Java SDK.  The flags will be in a nested struct called `flags` where the key is the name of the feature and the value is the current value.  If you pass `withReasons=true` to this method, the `flags` struct will have a nested struct for each flag containing `value` and `reason` keys similar to how `xxxVariationDetail()` works.

## Context Tracking

Pretty much all the SDK methods accept a struct called `context` which defines all the details of the current context.  In previous SDK versions, this was called `user`.

```js
var results = LD.booleanVariationDetail( 'my-feature', false, { key : 'brad-wood' } );

var flagData = LD.getAllFlags( { key : 'luis-majano' } )
```
However, the recommended approach is to use the `contextProvider` setting for the library which allows you to set a single UDF that returns all the details for whatever context is currently logged in.  In this way, you can have that logic all in one place, pulling from the session scope, or wherever you track the current context.  Returning an empty struct from your `contextProvider` UDF will create an "anonymous" context.

There are 3 "reserved" structure key names for context structures to be aware of: `key`, `kind`, and `privateAttributes`.

The only required key in your struct is `key` which needs to be unique to each context.  In the case of a user context, it should be a value that uniquely identifies the current user (e.g. the primary key of your users table).

You can also include a key named `kind` which defaults to "user", which is the legacy behavior of the SDK.  Any other custom string is allowed, so long as it is not the word "kind", "multi", and contains only letters, numbers, and ".", "-", "_".  Examples of non-user contexts would be device, organization, or location and would provide another way to create cross-cutting targeting of your users. See https://docs.launchdarkly.com/guides/flags/intro-contexts for more information

The `privateAttributes` key allows you to protect certain context keys from being sent to (and recorded by) LaunchDarkly.  See the 'Protecting Sensitive User/Context Information' below for more information.

All structure keys other than `key`, `kind`, and `privateAttributes` will be added as custom properties for your context.  Complex values will be serialized to JSON and added as an LDValue.  You can include anything you want here including the user's role, status, preferences, etc.  Any custom properties not flagged as `private` data will be available to browse/auto-suggest in the LaunchDarkly admin UI to create segments out of so you can target very specific groups of contexts such as "All admin users in Florida with purchases in the last 6 months" (note: you may still create targeting rules / segments using `private` attributes but you will not receive the benefit of the auto-suggest / browse functionality).

You can also use LaunchDarkly's multi-context features by specifying an array of context structs.  Each context follows the rules above and you can return an array of these context stucts anywhere a `context` argument is accepted or from the `contextProvider` UDF.

### Protecting Sensitive User/Context Information

While the LaunchDarkly SDK does not send user/context information to the LaunchDarkly service in order to perform the flag evaluations (this is done locally inside of the instantiated SDK object), it does transmit flag and user/context information (after the fact) to LaunchDarkly for observability and analytics purposes.  This can be a problem if you are planning on using/targeting attributes that could be considered sensitive or personal identifiable information (like email address, ip address, or user role).

To address this, the SDK allows you to mark user/context attributes as `private`.  Private attributes may still be used for targeting purposes, but will not be sent back to the LaunchDarkly service.

To exclude user/context attributes as private, append a specific key (`privateAttributes`) to your user/context structure.  This attribute accepts an array of property names (strings) to mark as `private`.  

For example:
```js
/* Note: This example shows how to use the `privateAttributes` key when passing the context object during flag evaluation (See 'Context Tracking' above).  If you are using the contextProvider() method, you would add a `privateAttributes` key to the structure that is output from that method (see example in 'Configuration' above)
*/
var myContextStruct = {
    'key' : 'user-12345',
    'email' : 'user@example.com',  
    'ip' : '127.0.0.1',
    'privateAttributes' : ["email", "ip"]
}
var results = LD.booleanVariationDetail( 'feature-that-targets-email', false, myContextStruct );
```

In the example above, LaunchDarkly account admins can create targeting rules in the LaunchDarkly Admin UI that delivers a specific variation to users whose email address match `user@example.com` (or that ends in the `@example.com` domain), but viewing the user/context record inside of the LaunchDarkly admin UI will not display the value of these attributes, thus allowing you to protect sensitive user/context information

### Backwards Compat

For backwards compatibility with older versions of the SDK, the following checks will be made:
* If there is a `userProver` setting, it will be used instead of the `contextProvider` setting.
* Any SDK method that accepts a `context` parameter, will use a `user` parameter first if it is provided as the context.

## Listening for flag changes

One of the cool features of the Launchdarkly SDK is you can "push" out events to your web app instantly when you make changes to flags inside the LD web dashboard.  There are two types of listeners you can register as a simple closure which will be run automatically when a flag updates.

* `registerFlagChangeListener()` - This is a generic listener that will be fired any time any data changes on any flag for any user.  It's up to you to pull the latest variations if you want to see what changed.  You just get the name of the flag that changed.
* `registerFlagValueChangeListener()` - This is a very specific listener that will tell you specifically when the flag variation value for a specific user changes.  You will receive the old and the new value to your closure.

```js
{
    SDKKey='my-key',
    flagChangeListener=( featureKey )=>writeDump( var="Flag [#featureKey#] changed!", output='console' ),
    flagValueChangeListeners=[
        {
            featureKey : 'test',
            user : { key : 12345 },
            udf : ( oldValue, newValue )=>writeDump( var="Flag [test] changed from [#oldValue#] to [#newValue#]!", output='console' )
        },
        {
            featureKey : 'another-feature',
            udf : ( oldValue, newValue )=>{}
        }
    ]
}
```


Note, for older versions of Adobe ColdFusion, you'll need to use this closure syntax:
```js
{
    SDKKey='my-key',
    flagChangeListener=function( featureKey ) {
        writeDump( var="Flag [#featureKey#] changed!", output='console' );
    },
    flagValueChangeListeners=[
        {
            featureKey : 'test',
            user : { key : 12345 },
            udf : function( oldValue, newValue ) {
                writeDump( var="Flag [test] changed from [#oldValue#] to [#newValue#]!", output='console' );
            }
        },
        {
            featureKey : 'another-feature',
            udf : function( oldValue, newValue ){

            }
        }
    ]
}
```

NOTE: If you don't shutdown the LD client properly, you will have old listener threads still in memory and firing.  Make sure you call `LD.shutdown()` if you're using the library outside of ColdBox (which manages these events for you).

## Misc

Here's some more SDK methods in example form:

```js
// Teach the SDK about a new user which will show up in the dashboard (useful for preloading users)
LD.identifyUser( { key : 12345, name : 'brad' } )

// Get the status of the underlying data store
var status = LD.getDataStoreStatus();

// Get the status of the underlying data source
var status = LD.getDataSourceStatus();

// Track a custom user event
LD.track( 'my-event' );

// Track a custom user event with arbitrary data
LD.track(
    eventName = 'my-event',
    data ={
        customData : true,
        foo : 'bar'
    }
);


// Track a custom user event with arbitrary data and metric value
LD.track(
    eventName = 'my-event',
    data = {
        customData : true,
        foo : 'bar'
    },
    metricValue = 42
);

// Check if a given feature flag exists
var exists = LD.isFlagKnown( 'maybe-this-exists' );

// Is the SDK offline?
var isDead = LD.isOffline();

// Flush all events to the web dashboard
LD.flush();
```
## Contributing
In you are interested in contributing to this module, this section outlines the process to get started:

### Before you begin
You will need: 
* Access to a CommandBox instance (https://www.ortussolutions.com/products/commandbox) to run the test suite for the modules
* a GitHub.com user account that you can use to open Pull Requests to submit changes to the source code repository.

### Set up your development environment
1. Create a fork of the LaunchDarklySDK repository in GitHub (https://github.com/coldbox-modules/LaunchDarklySDK)
2. Clone a copy of your fork of the repository to a working copy on your machine
3. Open the folder containing your working copy of the project in CommandBox or your command line tool of choice
4. Install the module's dependencies using the CLI command `box install` (note if you are running this command inside of CommandBox's built-in CLI you can exclude the `box` prefix)

### Running the module test suite
The expectations for this module are that all tests return successful for the automated testbox test suite included in this project.  Any changes to the project should include corresponding changes to the test suite as well.

1. Using CommandBox (or your Command Line Interface tool of choice), navigate to the working copy of this project.
2. Start up a temporary server to use to run the project's test suite using the command `box server start` (note if you are running this command inside of CommandBox's built-in CLI you can exclude the `box` prefix)
3. Wait until the server starts up and it should automatically open a browser window to the project's test suite.  If the browser does not open automatically, you can navigate to the test suite manually by opening the `http://{serverHost}:{serverPort}/tests/runner.cfm` URL in a browser.
4. All tests should initially be returning successful - please be sure to re-run the test suite before submitting a pull request for any changes and ensure that all tests are passing.

### Running the test suite in different CFML engines
By default, the temporary test suite server starts up using the latest version of the Lucee v5 CFML engine.  You can change which CFML engine is used to run the tests via the environment variable LDM_CFML_SERVER_ENGINE prior to starting the server

for example:
``` bash
SET LDM_CFML_SERVER_ENGINE=adobe@2023
box server start

# or 
SET LDM_CFML_SERVER_ENGINE=lucee@5
box server start
```
### Submitting your changes
Submit your changes for review by opening up a pull request of your fork to the main repository in GitHub.com