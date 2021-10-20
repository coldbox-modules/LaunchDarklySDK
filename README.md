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
* `userProvider` - A closure that returns a struct of user details for the current logged-in user.  The only required key is "key" which must be unique.
* `registerFlagChangeListener` - This is a generic listener that will be fired any time any data changes on any flag for any user. (more below)
* `registerFlagValueChangeListener()` - This is a very specific listener that will tell you specifically when the flag variation value for a specific user changes. (more below)

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

## Get all flags for a user

You can get all the flags and their current values for a user like so:

```js
var flagData = LD.getAllFlags()
```
The result will be a struct with an `isValid` key that comes from the underlying Java SDK.  The flags will be in a nested struct called `flags` where the key is the name of the feature and the value is the current value.  If you pass `withReasons=true` to this method, the `flags` struct will have a nested struct for each flag containing `value` and `reason` keys similar to how `xxxVariationDetail()` works.

## User Tracking

Pretty much all the SDK methods accept a struct called `user` which defines all the details of the current user.  

```js
var results = LD.booleanVariationDetail( 'my-feature', false, { key : 'brad-wood' } );

var flagData = LD.getAllFlags( { key : 'luis-majano' } )
```
However, the recommended approach is to use the `userProvider` setting for the library which allows you to set a single UDF that returns all the details for whatever user is currently logged in.  In this way, you can have that logic all in one place, pulling from the session scope, or wherever you track the current user.  Returning an empty struct from your `userProvider` UDF will create an "anonymous" user.  


The only required key in your struct is `key` which needs to be unique to each user.  It should ideally be the primary key of your users table.  The following keys will be mapped to the internal properties of the same name:

* `country`
* `avatar`
* `email`
* `firstName`
* `lastName`
* `name` -- Full name
* `ip`
* `secondary` -- The secondary key for a user.

All other keys will be added as custom properties.  Complex values will be serialized to JSON and added as an LDValue.  You can include anything you want here including the user's role, status, preferences, etc.  This data will be available in LaunchDarkly to create segments out of so you can target very specific groups of users such as "All admin users in Florida with purchases in the last 6 months".

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
