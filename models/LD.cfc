/**
*********************************************************************************
* Copyright Since 2021 Launch Darkly SDK by Brad Wood and Ortus Solutions, Corp
* www.ortussolutions.com
* ---
* This is the main Launch Darkly Client
*/
component accessors=true singleton {

	property name="wirebox" inject="wirebox";

	property name="settings";
	property name="coldbox";
	property name="isColdBoxLinked";
	property name="log";
    
	property name="LDClient";


    LDConfigBuilder = createObject( 'java', 'com.launchdarkly.sdk.server.LDConfig$Builder' );
    LDUserBuilder = createObject( 'java', 'com.launchdarkly.sdk.LDUser$Builder' );
    LDValue = createObject( 'java', 'com.launchdarkly.sdk.LDValue' );
    FlagsStateOption = createObject( 'java', 'com.launchdarkly.sdk.server.FlagsStateOption' );
    Duration = createObject( 'java', 'java.time.Duration' );
    LDComponents = createObject( 'java', 'com.launchdarkly.sdk.server.Components' );
    

	/**
	 * Constructor
	 */
	function init( struct settings={} ){
		setSettings( arguments.settings );
        setColdBox( '' );
        setWirebox( '' );
		// If we have settings passed to the init, this is likely not
		// in WireBox context so just configure now
		if( arguments.settings.count() ) {
			configure();
		}
		
		return this;
	}

	/**
	 * onDIComplete
	 */	
	function onDIComplete() {
		// If we have WireBox, see if we can get ColdBox
		if( !isNull( wirebox ) ) {
			// backwards compat with older versions of ColdBox 
			if( wirebox.isColdBoxLinked() ) {
			    setColdBox( wirebox.getColdBox() );
			    setSettings( wirebox.getInstance( dsl='box:moduleSettings:LaunchDarklySDK' ) );   
			}
		}
		
		configure();
	}


    /**
    * Configure this client!
    */
	function configure() {

        if( !isSimpleValue( getWirebox() ) ) {
            setLog( getWirebox().getLogBox().getLogger( this ) );
        } else {
            // Logbox shim for complete legacy mode
            setLog( {
                info : (message)=>_log(message,'info'),
                warn : (message)=>_log(message,'warn'),
                error : (message)=>_log(message,'error'),
                debug : (message)=>_log(message,'debug')
            } );
        }

        if( !isColdBoxLinked() ) {

            // Manully append default settings
            settings.append(
                getDefaultSettings(),
                false
            );
        }

        log.info( 'Launch Darkly SDK starting with the following config: #serializeJSON( settings )#' );

		if ( !len( settings.SDKKey ) ) {
   			log.warn( "Launch Darkly requires an SDK Key, going into [offline] mode." );
			settings.offline=true;
		}

        // https://launchdarkly.github.io/java-server-sdk/com/launchdarkly/sdk/server/integrations/HttpConfigurationBuilder.html
        HTTPConfig = LDComponents.httpConfiguration();

        var config = LDConfigBuilder
            .init()
            .offline( settings.offline )
            .startWait( Duration.ofMillis( settings.startWaitms ) )
            .diagnosticOptOut( settings.diagnosticOptOut )
            .http( HTTPConfig )
            .build();

        setLDClient( createObject( 'java', 'com.launchdarkly.sdk.server.LDClient' ).init( settings.SDKKey, config ) );

        // Register generic listener
        if( isCustomFunction( settings.flagChangeListener ) || IsClosure( settings.flagChangeListener ) ) {
            registerFlagChangeListener( settings.flagChangeListener );
        }

        // Register any specific flag change listeners
        settings.flagValueChangeListeners.each( (fcl)=>registerFlagValueChangeListener( argumentCollection=fcl ) );

	}

    /**
    * Is this client linked to ColdBox?
    *
    * @returns true if Coldbox is linked
    */
    function isColdBoxLinked() {
        return !isSimpleValue( getColdBox() );
    }

    /**
    * Get the default settings for the client.  This is only used when outside
    * of ColdBox and will read the "settings" struct from the ModuleConfig.cfc to 
    * mimic how ColdBox loads default module settings
    *
    * 
    * @returns A struct of default settings, or an empty struct if an error occurs reading the default settings.
    */
    function getDefaultSettings() {
        // All default settings externalized into this CFC for non-ColdBox reuse
        return new config.Settings().configure();
    }

    /**
    * A logbox shim when used outside of WireBox
    */
    private function _log( required message, type='debug' ) {
		writeDump( var="[#uCase( type )#] #message#", output='console' );
    }

    /**
    * Create an LDUser object out of a struct of properties.  If no properties are 
    * passed, the default userProvider UDF will be used.
    * 
    * The following keys will be mapped to the internal properties of the same name
    *   - country
        - avatar
        - email
        - firstName
        - lastName
        - name
        - ip
        - secondary
    *
    * All other keys will be added as custom properties.  Complex values will be 
    * serialized to JSON and added as an LDValue
    *
    * @userProps A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns An LDUser object
    * https://launchdarkly.github.io/java-server-sdk/com/launchdarkly/sdk/LDUser.html
    */
    private function buildLDUser( userProps={} ) {

        if( isNull( userProps ) || !userProps.count() ) {
            userProps = settings.userProvider();
        }

        if( userProps.count() && !userProps.keyExists( 'key' ) ) {
            throw( "Launch Darkly requires a unique [key] propery to identify your user." );
        }

        // Anon user
        if( !userProps.count() ) {
            return LDUserBuilder
                .init( 'anonymous' )
                .anonymous( true )
                .build();
        } else {
            var user = LDUserBuilder
                .init( userProps.key );
            
            userProps = duplicate( userProps );

            if( userProps.keyExists( 'country' ) ) {
                user.country( userProps.country );
                userProps.delete( 'country' );
            }
            if( userProps.keyExists( 'avatar' ) ) {
                user.avatar( userProps.avatar );
                userProps.delete( 'avatar' );
            }
            if( userProps.keyExists( 'email' ) ) {
                user.email( userProps.email );
                userProps.delete( 'email' );
            }
            if( userProps.keyExists( 'firstName' ) ) {
                user.firstName( userProps.firstName );
                userProps.delete( 'firstName' );
            }
            if( userProps.keyExists( 'lastName' ) ) {
                user.lastName( userProps.lastName );
                userProps.delete( 'lastName' );
            }
            if( userProps.keyExists( 'name' ) ) {
                user.name( userProps.name );
                userProps.delete( 'name' );
            }
            if( userProps.keyExists( 'ip' ) ) {
                user.ip( userProps.ip );
                userProps.delete( 'ip' );
            } else {
                user.ip( CGI.REMOTE_ADDR );
            }
            if( userProps.keyExists( 'secondary' ) ) {
                user.secondary( userProps.secondary );
                userProps.delete( 'secondary' );
            }

            // All aditional properties are custom fields
            for( var name in userProps ) {
                var value = userProps[ name ];
                if( isSimpleValue( value ) ) {
                    user.custom( javaCast( 'string', name ), value );
                } else {
                    // Turn complex values into JSON
                    user.custom( javaCast( 'string', name ), DValue.parse( serializeJSON( value ) ) );
                }
            }
            return user.build();
        }
    }

    function buildEvaluationDetail( required evaluationDetail ) {
        var result = {};
        var reason = evaluationDetail.getReason();
        if( evaluationDetail.getValue().getClass().getName().startsWith( 'com.launchdarkly.sdk.LDValue' ) ) {
            result[ 'value' ] = deserializeJSON( evaluationDetail.getValue().toJsonString() );
        } else {
            result[ 'value' ] = evaluationDetail.getValue();
        }
        result[ 'detail' ] = evaluationDetail.toString();
        result[ 'variationIndex' ] = evaluationDetail.getVariationIndex() ?: '';
        result[ 'isDefault' ] = evaluationDetail.isDefaultValue() ?: '';
        
        result[ 'reason' ] = {};
        result.reason[ 'detail' ] = reason.toString();
        result.reason[ 'exception' ] = reason.getException() ?: '';
        result.reason[ 'prerequisiteKey' ] = reason.getPrerequisiteKey() ?: '';
        result.reason[ 'ruleId' ] = reason.getRuleId() ?: '';
        result.reason[ 'ruleIndex' ] = reason.getRuleIndex() ?: '';
        result.reason[ 'isInExperiment' ] = reason.isInExperiment();
        result.reason[ 'kind' ] = reason.getKind()?.name() ?: '';
        result.reason[ 'errorKind' ] = reason.getErrorKind()?.name() ?: '';

        return result;
    }

    /* *****************************************************************************
    * SDK Methods
    ******************************************************************************** */

    
    /**
    * Get a variation
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A boolean representing the matching variation
    */
    any function variation(
        required string featureKey,
        required any defaultValue,
        struct user={}
    ) {
        return JSONVariation( argumentCollection=arguments );
    }
    
    /**
    * Get a variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A struct contaning the explanation in a "detail" key and a boolean representing the matching variation in a "value" key.
    */
    struct function variationDetail(
        required string featureKey,
        required any defaultValue,
        struct user={}
    ) {
        return JSONVariationDetail( argumentCollection=arguments );
    }


    /**
    * Get a string variation
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A string representing the matching variation
    */
    string function stringVariation(
        required string featureKey,
        required string defaultValue,
        struct user={}
    ) {
        return getLDClient()
            .stringVariation(
                javaCast( 'string', featureKey ),
                buildLDUser( user ),
                javaCast( 'string', defaultValue )
            );
    }
    
    /**
    * Get a boolean variation
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A boolean representing the matching variation
    */
    boolean function booleanVariation(
        required string featureKey,
        required boolean defaultValue,
        struct user={}
    ) {
        return getLDClient()
            .boolVariation(
                javaCast( 'string', featureKey ),
                buildLDUser( user ),
                javaCast( 'boolean', defaultValue )
            );
    }
    
    /**
    * Get a numeric variation
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A number representing the matching variation
    */
    numeric function numberVariation(
        required string featureKey,
        required numeric defaultValue,
        struct user={}
    ) {
        return getLDClient()
            .doubleVariation(
                javaCast( 'string', featureKey ),
                buildLDUser( user ),
                javaCast( 'double', defaultValue )
            );
    }
    
    /**
    * Get a JSON variation
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default. Can be JSON or any complex value
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A deserialized object representing the matching variation
    */
    any function JSONVariation(
        required string featureKey,
        required any defaultValue,
        struct user={}
    ) {
        if( !isJSON( defaultValue ) ) {
            defaultValue = serializeJSON( defaultValue );
        }

        // Returns an LDValue instance
        // https://launchdarkly.github.io/java-server-sdk/com/launchdarkly/sdk/LDValue.html
        var result = getLDClient()
            .jsonValueVariation(
                javaCast( 'string', featureKey ),
                buildLDUser( user ),
                LDValue.parse( defaultValue )
            );

        return deserializeJSON( result.toJsonString() );
    }


    /**
    * Get a string variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A struct contaning the explanation in a "detail" key and a string representing the matching variation in a "value" key.
    */
    struct function stringVariationDetail(
        required string featureKey,
        required string defaultValue,
        struct user={}
    ) {
        var result = {};
        var evaluationDetail = getLDClient()
            .stringVariationDetail(
                javaCast( 'string', featureKey ),
                buildLDUser( user ),
                javaCast( 'string', defaultValue )
            );
        return buildEvaluationDetail( evaluationDetail );
    }
    
    /**
    * Get a boolean variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A struct contaning the explanation in a "detail" key and a boolean representing the matching variation in a "value" key.
    */
    struct function booleanVariationDetail(
        required string featureKey,
        required boolean defaultValue,
        struct user={}
    ) {
        var result = {};
        var evaluationDetail = getLDClient()
            .boolVariationDetail(
                javaCast( 'string', featureKey ),
                buildLDUser( user ),
                javaCast( 'boolean', defaultValue )
            );
        return buildEvaluationDetail( evaluationDetail );
    }
    
    /**
    * Get a numeric variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A struct contaning the explanation in a "detail" key and a number representing the matching variation in a "value" key.
    */
    struct function numberVariationDetail(
        required string featureKey,
        required numeric defaultValue,
        struct user={}
    ) {
        var result = {};
        var evaluationDetail = getLDClient()
            .doubleVariationDetail(
                javaCast( 'string', featureKey ),
                buildLDUser( user ),
                javaCast( 'double', defaultValue )
            );
        return buildEvaluationDetail( evaluationDetail );
    }
    
    /**
    * Get a JSON variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default. Can be JSON or any complex value
    * @user A struct containing at least a "key" key to uniquely identify the user
    *
    * @returns A struct contaning the explanation in a "detail" key and a deserialized object representing the matching variation in a "value" key.
    */
    struct function JSONVariationDetail(
        required string featureKey,
        required any defaultValue,
        struct user={}
    ) {
        if( !isJSON( defaultValue ) ) {
            defaultValue = serializeJSON( defaultValue );
        }

        var result = {};
        var evaluationDetail = getLDClient()
            .jsonValueVariationDetail(
                javaCast( 'string', featureKey ),
                buildLDUser( user ),
                LDValue.parse( defaultValue )
            );
        return buildEvaluationDetail( evaluationDetail );
    }

    
    /**
    * Get all flags for a user
    *
    * @user A struct containing at least a "key" key to uniquely identify the user
    * @clientSideOnly Specifies that only flags marked for use with the client-side SDK should be included in the state object.
    * @detailsOnlyForTrackedFlags pecifies that any flag metadata that is normally only used for event generation - such as flag versions and evaluation reasons - should be omitted for any flag that does not have event tracking or debugging turned on.
    * @withReasons Specifies that EvaluationReason data should be captured in the state object.
    *
    * @returns A struct
    */
    struct function getAllFlags(
        struct user={},
        boolean clientSideOnly=false,
        boolean detailsOnlyForTrackedFlags=false,
        boolean withReasons=false
    ) {

        var result = {};
        var options = [];
        if( clientSideOnly ) {
            options.append( FlagsStateOption.CLIENT_SIDE_ONLY );
        }
        if( clientSideOnly ) {
            options.append( FlagsStateOption.DETAILS_ONLY_FOR_TRACKED_FLAGS );
        }
        if( withReasons ) {
            options.append( FlagsStateOption.WITH_REASONS );
        }
        var featureFlagsState = getLDClient()
            .allFlagsState( buildLDUser( user ), options );

        
        result[ 'isValid' ] = featureFlagsState.isValid();
        result[ 'flags' ] = structMap( featureFlagsState.toValuesMap(), (k,v)=>{
            if( !withReasons ) {
                return deserializeJSON( v.toJSONString() );
            }
            return {
                'value': deserializeJSON( v.toJSONString() ),
                'reason': featureFlagsState.getFlagReason( k ).toString()
            }
         } );
        return result;
    }
    
    /**
    * creates or updates users in LaunchDarkly, which makes them available for targeting and autocomplete on the dashboard.
    *
    * @user A struct containing at least a "key" key to uniquely identify the user
    */
    function identifyUser(
        struct user={}
    ) {
        getLDClient()
            .identify( buildLDUser( user ) );
    }
    
    /**
    * Get's the status of the SDK's data store
    *
    * @user A struct with the keys isAvailable, isRefreshNeeded, and detail
    */
    function getDataStoreStatus() {
        var result = {};
        var status = getLDClient()
            .getDataStoreStatusProvider().getStatus();
        result[ 'isAvailable' ] = status.isAvailable();
        result[ 'isRefreshNeeded' ] = status.isRefreshNeeded();
        result[ 'detail' ] = status.toString();
        return result;
    }
    
    /**
    * Get's the status of the SDK's data source
    *
    * @user A struct with the keys isAvailable, isRefreshNeeded, and detail
    */
    function getDataSourceStatus() {
        var result = {};
        var status = getLDClient()
            .getDataSourceStatusProvider().getStatus();
        result[ 'state' ] = status.getState().name();
        result[ 'stateSince' ] = status.getStateSince().toString();
        result[ 'lastError' ] = '';
        if( !isNull( status.getLastError() ) ) {
            result[ 'lastError' ] = status.getLastError().toString();
        }                
        result[ 'detail' ] = status.toString();
        return result;
    }
    
    /**
    * Tracks that a user performed an event.
    *
    * @eventName the name of the event
    * @user A struct containing at least a "key" key to uniquely identify the user
    * @data additional data associated with the event.  Can be simple or complex values
    * @metricValue a numeric value used by the LaunchDarkly experimentation feature in numeric custom metrics. Can be omitted if this event is used by only non-numeric metrics. This field will also be returned as part of the custom event for Data Export.
    */
    function track(
        required string eventName,
        struct user={},
        any data,
        numeric metricValue
    ) {

        user = buildLDUser( user );
        if( !isNull( data ) && !isJSON( data ) ) {
            data = LDValue.parse( serializeJSON( data ) );
        }

        if( !isNull( metricValue ) ) {
            getLDClient()
                .trackMetric(
                    javaCast( 'string', eventName ),
                    user,
                    ( isNull( data ) ? javaCast( 'null', '' ) : data ),
                    javaCast( 'double', metricValue )
                );
        } else if( !isNull( data ) ) {
            getLDClient()
                .trackData(
                    javaCast( 'string', eventName ),
                    user,
                    data    
                );
        } else {
            getLDClient()
                .track(
                    javaCast( 'string', eventName ),
                    user
                );
        }

    }

    /**
    * Returns true if the specified feature flag currently exists..
    * 
    * @featureKey Name of the feature key you'd like to check
    */
    function isFlagKnown(
        required string featureKey
    ) {
        return getLDClient()
            .isFlagKnown(
                javaCast( 'string', featureKey )
            );
    }

    /**
    * Registers a listener to be notified of feature flag changes in general.
    * The listener will be notified whenever the SDK receives any change to any feature flag's configuration, or to a user segment that is referenced by a feature flag.
    * If the updated flag is used as a prerequisite for other flags, the SDK assumes that those flags may now behave differently and sends flag change events for them as well.
    * 
    * Note that this does not necessarily mean the flag's value has changed for any particular user, only that some part of the flag configuration was changed so that 
    * it may return a different value than it previously returned for some user. 
    *
    * @udf A closure which will be called any time a change is made to a flag in the LauchDarkly dashboard. The closure will receive the name of the flag as a string.
    * 
    */
    function registerFlagChangeListener(
        required udf
    ) {
        return getLDClient()
            .getFlagTracker()
            .addFlagChangeListener( 
                createDynamicProxy(
					new proxies.FlagChangeListener( arguments.udf ),
					[ "com.launchdarkly.sdk.server.interfaces.FlagChangeListener" ]
				)
             );
    }


    /**
    * Registers a listener to be notified of a change in a specific feature flag's value for a specific set of user properties.
    * When you call this method, it first immediately evaluates the feature flag. It then uses a flag change listener to start listening for feature 
    * flag configuration changes, and whenever the specified feature flag changes, it re-evaluates the flag for the same user.
    * It then calls your FlagValueChangeListener if and only if the resulting value has changed.
    *
    * @featureKey Name of the feature key you'd like to monitor
    * @udf A closure which will be called any time a flag value changes for a given user and featureKey.  The closure will receive two args-- the old value and new value
    * @user A struct containing at least a "key" key to uniquely identify the user
    * 
    */
    function registerFlagValueChangeListener(
        required string featureKey,
        required udf,
        struct user={}
    ) {
        return getLDClient()
            .getFlagTracker()
            .addFlagValueChangeListener( 
                javaCast( 'string', featureKey ),
                buildLDUser( user ),
                createDynamicProxy(                    
					new proxies.FlagValueChangeListener( arguments.udf ),
					[ "com.launchdarkly.sdk.server.interfaces.FlagValueChangeListener" ]
				)                
             );
    }

    /**
    * Returns true if the client is in offline mode.
    */
    function isOffline() {
        return getLDClient().isOffline();
    }

    /**
    * Flushes all pending events.
    */
    function flush() {
        getLDClient().flush();
    }

    /**
    * Shuts down the LD Client.  This MUST be called in order to release internal resources
    */
    function shutdown() {
        log.info( 'Launch Darkly SDK shutting down.' );
        flush();
        getLDClient().close();
    }

}
