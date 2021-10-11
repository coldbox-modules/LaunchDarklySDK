# LaunchDarkly CFML SDK

A CFML SDK for LaunchDarkly feature flags

## Requirements

This should run on Lucee and versions of Adobe CF modern enough to support arrow functions (2021 and 2018 Update 5+).
The SDK is set up as a ColdBox module, however it will also work with WireBox standalone or just a legacy app. 

## Installation

Use CommandBox to install it:
```bash
install launchdarklysdk
```

If your allergic to CLI's, you can snag the code from Github or Forgebox, but it will be up to you to acqure the jar file referenced in the `box.json`.

Since I hate using javaloader in The Year of Our Lord 2021, you must manually add the jars to your `Application.cfc`'s `this.javaSettings`.  This can be done pretty quickly with a little snippet like so (adjust the paths as neccessary):
```js
	this.javaSettings = {
		loadPaths = directorylist( expandPath( '/modules/LaunchDarklySDK/lib' ), true, 'array', '*jar' ),
		loadColdFusionClassPath = true,
		reloadOnChange = false
	};
```

## Usage

If you're a cool kid and using ColdBox, you can just inject the client class (called `LD`)...

```js
property name="LD" inject="LD@LaunchDarklySDK";
```
and start using it...
```
if( LD.stringVariation( 'my-feature-flag' ) ) {
    // enable awesomeness
}
```
The module will automatically shutdown the client when ColdBox reinits via the unicorn magic of ColdBox intercptors.  
Configure the client in a ColdBox setting by adding to your `moduleSettings` struct in `/config/Coldbox.cfc`.

```js
moduleSettings = {
  'LaunchDarklySDK' : {
      SDKKey : 'my-key-here'
  }
};
```

If you're using this library outside of ColdBox, there's a couple things you'll need to do manally.

### Create the client CFC 

ONLY DO THIS ONCE AND STORE IT AS A SINGLETON.
Pass your configuration as a struct to the constructor.  The key names and values are the same as what you'd put in the ColdBox config.

```
application.LD = new models.LD( {
	SDKKey:'my-key-here'
});
```

### Shutdown the client before re-creating it

If you have code that re-creates your application like a framework reinit, you'll want to shutdown the old LD client CFC to release underlying resources before you recreate it again.

```js
application.LD.shutdown();
```

## Configuration

Here's a list of the currently-support config items:

* `SDKKey` - Required-- your SDK Key from LaunchDarkly
* `diagnosticOptOut` - Set to true to opt out of sending diagnostics data.
* `startWaitms` - Set how long in miliseoncd the constructor will block awaiting a successful connection to LaunchDarkly.
* `offline` - Set whether this client is offline.
* `userProvider` - A closure that returns a struct of user details for the current logged-in user.  The only required key is "key" which must be unique.

```js
{
        SDKKey : 'my-key',
        userProvider=()=>{
            if( session.keyExists( 'user' ) ) {
                return {
                    key : session.user.id,
                    name : session.user.fullname,
                    email : session.user.email,
                    country : session.user.country,
                };
            } else {
                // Anonymous
                return {};
            }
        }
}
```

## Check feature variations

Since we wrap the Java SDK which is strictly typed, you need to use a different method based on whether you are getting a feature variant that is a string, boolean, number, or JSON.  The methods all work the same, the types are just different.  Check your LaunchDarkly admin UI to see which type a given feature is created as.  A default value that matches the feature type is always required.

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

You can get a reason for the current result by calling the "details" version of each method.


```js
var results = LD.booleanVariationDetail( 'my-feature', false );
if( results.value ) {
    writeOutput( 'Enabled because of #results.detail#' );
} else {
    writeOutput( 'Disabled because of #results.detail#' );
}
```

The `JSONVariation()` method will accept a complex value as the "default" and will also deserialize whatever JSON is stored in the variation so you get back a proper struct or array.

## Get all flags for a user

You can get all the flags and their current values for a user like so:

```js
var flags = LD.getAllFlags()
```
The result will be a struct with an `isValid` key that comes from the underlying Java SDK.  The flags will be in a nested struct called `flags` where the key is the name of the feature and the value is the current value.  If you pass `withReasons=true` to this method, the `flags` struct will have a nested struct for each flag containing `value` and `reason` keys similar to how `xxxVariationDetail()` works.

## Misc

Here's some more SDK methdos in example form:

```js
// Teach the SDK about a new user which will show up in the dashboard (useful for preloading users)
LD.identifyUser( { key : 12345, name : 'brad' } )

// Get the status of the underlying data store
var status = LD.getDataStoreStatus();

// Get the status of the underlying data source
var status = LD.getDataSouceStatus();

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