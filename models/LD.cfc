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
	property name="testData";
	property name="LDValue";


    LDConfigBuilder = createObject( 'java', 'com.launchdarkly.sdk.server.LDConfig$Builder' );
    LDContext = createObject( 'java', 'com.launchdarkly.sdk.LDContext' );
    LDContextKind = createObject( 'java', 'com.launchdarkly.sdk.ContextKind' );
    LDValue = createObject( 'java', 'com.launchdarkly.sdk.LDValue' );
    FlagsStateOption = createObject( 'java', 'com.launchdarkly.sdk.server.FlagsStateOption' );
    Duration = createObject( 'java', 'java.time.Duration' );
    LDComponents = createObject( 'java', 'com.launchdarkly.sdk.server.Components' );
    FileData = createObject( 'java', 'com.launchdarkly.sdk.server.integrations.FileData' );
    DuplicateKeysHandling = createObject( 'java', 'com.launchdarkly.sdk.server.integrations.FileData$DuplicateKeysHandling' );
    LDTestData = createObject( 'java', 'com.launchdarkly.sdk.server.integrations.TestData' );


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
                info : function(message){_log(message,'info');},
                warn : function(message){_log(message,'warn');},
                error : function(message){_log(message,'error');},
                debug : function(message){_log(message,'debug');}
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

		if ( !len( settings.SDKKey ) && ( settings.datasource.type ?: '' ) == 'default' ) {
   			log.warn( "Launch Darkly requires an SDK Key, going into [offline] mode." );
			settings.offline=true;
		}

        // https://launchdarkly.github.io/java-server-sdk/com/launchdarkly/sdk/server/integrations/HttpConfigurationBuilder.html
        HTTPConfig = LDComponents.httpConfiguration();

        var configBuilder = LDConfigBuilder
            .init()
            .offline( settings.offline )
            .startWait( Duration.ofMillis( settings.startWaitms ) )
            .diagnosticOptOut( settings.diagnosticOptOut )
            .http( HTTPConfig );

        if( !isNull( settings.datasource.type ) ) {
            if( settings.datasource.type == 'testData' ) {
                setTestData( LDTestData.dataSource() );
                configBuilder.dataSource( getTestData() );
            } else if( settings.datasource.type == 'fileData' ) {
                settings.datasource.fileDataPaths = settings.datasource.fileDataPaths ?: [];
                if( isSimpleValue( settings.datasource.fileDataPaths ) ) {
                    settings.datasource.fileDataPaths = listToArray( settings.datasource.fileDataPaths );
                }
                if( !settings.datasource.fileDataPaths.len() ) {
                    throw( message="No Launch Darkly fileDataPaths specified.", type='launchDarkly.missingFileDataPath' );
                }
                settings.datasource.fileDataPaths.each( function(p){
                    if( !fileExists( p ) ) {
                        throw( message="Launch Darkly fileDataPath [#p#] is invalid (does not exist).", type='launchDarkly.invalidFileDataPath' );
                    }
                } );

                // Can't use elvis operator on booleans because Adobe CF is stupid!
                if( isNull( settings.datasource.fileDataIgnoreDuplicates ) ) {
                    settings.datasource.fileDataIgnoreDuplicates = true;
                }
                // Can't use elvis operator on booleans because Adobe CF is stupid!
                if( isNull( settings.datasource.fileDataAutoUpdate ) ) {
                    settings.datasource.fileDataAutoUpdate = false;
                }

                configBuilder.dataSource(
                    fileData.datasource()
                        .filePaths( javacast( 'String[]', settings.datasource.fileDataPaths ) )
                        .autoUpdate( settings.datasource.fileDataAutoUpdate )
                        .duplicateKeysHandling( settings.datasource.fileDataIgnoreDuplicates ? DuplicateKeysHandling.IGNORE : DuplicateKeysHandling.FAIL )
                       );

            } else if( settings.datasource.type != 'default' ) {
                throw( message="Unkown Launch Darkly datasource type [#settings.datasource.type#].", detail="Valid datasoruce types are default, fileData, and testData", type='launchDarkly.invalidDatasourceType' );
            }
        }

        var config = configBuilder.build();

        setLDClient( createObject( 'java', 'com.launchdarkly.sdk.server.LDClient' ).init( settings.SDKKey, config ) );

        // Register generic listener
        if( isCustomFunction( settings.flagChangeListener ) || IsClosure( settings.flagChangeListener ) ) {
            registerFlagChangeListener( settings.flagChangeListener );
        }

        // Register any specific flag change listeners
        settings.flagValueChangeListeners.each( function(fcl){registerFlagValueChangeListener( argumentCollection=fcl );} );

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
    * Create an LDContext object out of a struct of properties.  If no properties are
    * passed, the default contextProvider UDF will be used.
    *
    * All keys other than "key" and "kind" will be added as custom properties.  Complex values will be
    * serialized to JSON and added as an LDValue
    *
    * @contextProps A struct containing at least a "key" key to uniquely identify the context. Can also be an array of structs which will create a multi-context.
    *
    * @returns An LDContext object
    * https://javadoc.io/doc/com.launchdarkly/launchdarkly-java-server-sdk/6.0.0/com/launchdarkly/sdk/LDContext.html
    */
    private function buildLDContext( any contextProps={} ) {

        // If there is no context provided, or it is empty, check for a context provider.
        if( isNull( contextProps ) || ( isStruct( contextProps ) && !contextProps.count() ) ) {
            // Backwards compat for old closure name
            if( !isNull( settings.userProvider ) ) {
                contextProps = settings.userProvider();
            } else {
                contextProps = settings.contextProvider();
            }
        }

        // Now that we have a context, check if it is a mulit-context
        if( isArray( contextProps ) ) {
            // Build each struct into an array and then assemble a multi-context from them
            return LDContext.createMulti( contextProps.map( (c)=>buildLDContext( c ) ) );
        }

        if( contextProps.count() && !contextProps.keyExists( 'key' ) ) {
            throw( message="Launch Darkly requires a unique [key] propery to identify your context.", type='launchDarkly.invalidContextMissingKey' );
        }
        var contextKind = LDContextKind.DEFAULT;
        if( !isNull( contextProps.kind ) ) {
            if( reFind( '[^a-zA-Z0-9\._-]', contextProps.kind ) || contextProps.kind == 'kind' || contextProps.kind == 'multi' ) {
                throw( message='The context kind [#contextProps.kind#] is invalid.  Only letters, numbers, and the characters ".", "_", and "-" are allowed and the kind cannot be the string "kind" or "mulit".', type='launchDarkly.invalidContextKind' );
            }
            contextKind = LDContextKind.of( contextProps.kind );
        }

        // Anon context
        if( !contextProps.count() ) {
            return LDContext.builder( contextKind, 'anonymous' )
                .anonymous( true )
                .build();
        } else {
            var context = LDContext.builder( contextKind, javaCast( 'string', contextProps.key ) );

            contextProps = duplicate( contextProps );

            contextProps.delete( 'key' );

            if( contextKind.toString() == 'user' && !contextProps.keyExists( 'ip' ) ) {
                contextProps['ip'] = CGI.REMOTE_ADDR;
            }

            /* A note about handling private attriubtes in LaunchDarkly:
               LD supports the abilityh to define context properties/attributes as "private"
               this means that these attributes may be used for targeting purposes but will
               not be sent to LaunchDarkly as part of it's SDK telemetry and analytics data.
               This is meant to allow us to use context attributes that include PII (like email)
               without having it reside in LaunchDarkly's context database.  To mark an attribute
               as private, provide an additional context property called `privateAttributes` that 
               includes an array of property names to be treated as private */
            var privateAttributes = [];
            if ( contextProps.keyExists("privateAttributes") && isArray(contextProps.privateAttributes) ) {
                privateAttributes = contextProps.privateAttributes;
                context.privateAttributes( javaCast('string[]', privateAttributes) );
                contextProps.delete( "privateAttributes" );
            }
            
            // All aditional properties are custom fields
            if( settings.contextExplodeStructAttributes ) {
                storeCustomcontextAttributeLegacy( '', contextProps, context );
            } else {
                storeCustomContextAttribute( contextProps, context );
            }


            return context.build();
        }
    }

    private function storeCustomcontextAttribute( any contextProps, any context ) {
        contextProps.each( ( name, value )=>{
            if( isSimpleValue( value ) ) {
                context.set( javaCast( 'string', name ), value );
            } else if( isArray( value ) || isStruct( value ) ) {
                context.set( javaCast( 'string', name ), LDValue.parse( serializeJSON( value ) ) );
            } else {
                throw( message="Launch Darkly custom context attribute [#name#] is of invalid type.  Only simple values, arrays, and structs are allowed.", type='launchDarkly.invalidContextPropertyType' );
            }
        } );
    }

    private function storeCustomcontextAttributeLegacy( string name, any value, any context ) {
        if( isSimpleValue( value ) ) {
            context.set( javaCast( 'string', name ), value );
        } else if( isArray( value ) ) {
            context.set( javaCast( 'string', name ), LDValue.parse( serializeJSON( value ) ) );
        } else if( isStruct( value ) ) {
            for( var key in value ) {
                // Turn myStruct = { foo : 'bar' } into myStruct.foo = 'bar'
                storeCustomContextAttribute( listAppend( name, key, '.' ), value[ key ], context );
            }
        } else {
            throw( message="Launch Darkly custom context attribute [#name#] is of invalid type.  Only simple values, arrays, and structs are allowed.", type='launchDarkly.invalidContextPropertyType' );
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
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A boolean representing the matching variation
    */
    any function variation(
        required string featureKey,
        required any defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        return JSONVariation( argumentCollection=arguments );
    }

    /**
    * Get a variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A struct contaning the explanation in a "detail" key and a boolean representing the matching variation in a "value" key.
    */
    struct function variationDetail(
        required string featureKey,
        required any defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        return JSONVariationDetail( argumentCollection=arguments );
    }


    /**
    * Get a string variation
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A string representing the matching variation
    */
    string function stringVariation(
        required string featureKey,
        required string defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        return getLDClient()
            .stringVariation(
                javaCast( 'string', featureKey ),
                buildLDContext( context ),
                javaCast( 'string', defaultValue )
            );
    }

    /**
    * Get a boolean variation
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A boolean representing the matching variation
    */
    boolean function booleanVariation(
        required string featureKey,
        required boolean defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        return getLDClient()
            .boolVariation(
                javaCast( 'string', featureKey ),
                buildLDContext( context ),
                javaCast( 'boolean', defaultValue )
            );
    }

    /**
    * Get a numeric variation
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A number representing the matching variation
    */
    numeric function numberVariation(
        required string featureKey,
        required numeric defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        return getLDClient()
            .doubleVariation(
                javaCast( 'string', featureKey ),
                buildLDContext( context ),
                javaCast( 'double', defaultValue )
            );
    }

    /**
    * Get a JSON variation
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default. Can be JSON or any complex value
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A deserialized object representing the matching variation
    */
    any function JSONVariation(
        required string featureKey,
        required any defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        if( !isJSON( defaultValue ) ) {
            defaultValue = serializeJSON( defaultValue );
        }

        // Returns an LDValue instance
        // https://launchdarkly.github.io/java-server-sdk/com/launchdarkly/sdk/LDValue.html
        var result = getLDClient()
            .jsonValueVariation(
                javaCast( 'string', featureKey ),
                buildLDContext( context ),
                LDValue.parse( defaultValue )
            );

        return deserializeJSON( result.toJsonString() );
    }


    /**
    * Get a string variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A struct contaning the explanation in a "detail" key and a string representing the matching variation in a "value" key.
    */
    struct function stringVariationDetail(
        required string featureKey,
        required string defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        var result = {};
        var evaluationDetail = getLDClient()
            .stringVariationDetail(
                javaCast( 'string', featureKey ),
                buildLDContext( context ),
                javaCast( 'string', defaultValue )
            );
        return buildEvaluationDetail( evaluationDetail );
    }

    /**
    * Get a boolean variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A struct contaning the explanation in a "detail" key and a boolean representing the matching variation in a "value" key.
    */
    struct function booleanVariationDetail(
        required string featureKey,
        required boolean defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        var result = {};
        var evaluationDetail = getLDClient()
            .boolVariationDetail(
                javaCast( 'string', featureKey ),
                buildLDContext( context ),
                javaCast( 'boolean', defaultValue )
            );
        return buildEvaluationDetail( evaluationDetail );
    }

    /**
    * Get a numeric variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A struct contaning the explanation in a "detail" key and a number representing the matching variation in a "value" key.
    */
    struct function numberVariationDetail(
        required string featureKey,
        required numeric defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        var result = {};
        var evaluationDetail = getLDClient()
            .doubleVariationDetail(
                javaCast( 'string', featureKey ),
                buildLDContext( context ),
                javaCast( 'double', defaultValue )
            );
        return buildEvaluationDetail( evaluationDetail );
    }

    /**
    * Get a JSON variation and detail explanation of why it was chosen
    *
    * @featureKey Name of the feature key you'd like to check
    * @defaultvalue The value to return by default. Can be JSON or any complex value
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    * @returns A struct contaning the explanation in a "detail" key and a deserialized object representing the matching variation in a "value" key.
    */
    struct function JSONVariationDetail(
        required string featureKey,
        required any defaultValue,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        if( !isJSON( defaultValue ) ) {
            defaultValue = serializeJSON( defaultValue );
        }

        var result = {};
        var evaluationDetail = getLDClient()
            .jsonValueVariationDetail(
                javaCast( 'string', featureKey ),
                buildLDContext( context ),
                LDValue.parse( defaultValue )
            );
        return buildEvaluationDetail( evaluationDetail );
    }


    /**
    * Get all flags for a context
    *
    * @context A struct containing at least a "key" key to uniquely identify the context
    * @clientSideOnly Specifies that only flags marked for use with the client-side SDK should be included in the state object.
    * @detailsOnlyForTrackedFlags pecifies that any flag metadata that is normally only used for event generation - such as flag versions and evaluation reasons - should be omitted for any flag that does not have event tracking or debugging turned on.
    * @withReasons Specifies that EvaluationReason data should be captured in the state object.
    *
    * @returns A struct
    */
    struct function getAllFlags(
        any context={},
        boolean clientSideOnly=false,
        boolean detailsOnlyForTrackedFlags=false,
        boolean withReasons=false
    ) {

        arguments.context = arguments.user ?: arguments.context;
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
            .allFlagsState( buildLDContext( context ), options );


        result[ 'isValid' ] = featureFlagsState.isValid();
        result[ 'flags' ] = structMap( featureFlagsState.toValuesMap(), function(k,v){
            if( !withReasons ) {
                return deserializeJSON( v.toJSONString() );
            }
            return {
                'value': deserializeJSON( v.toJSONString() ),
                'reason': featureFlagsState.getFlagReason( k ).toString()
            };
         } );
        return result;
    }

    /**
    * creates or updates contexts in LaunchDarkly, which makes them available for targeting and autocomplete on the dashboard.
    *
    * @context A struct containing at least a "key" key to uniquely identify the context
    */
    function identifyContext(
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        getLDClient()
            .identify( buildLDContext( context ) );
    }

    /**
    * DEPRECATED: Backwards compat. Use identifyContext() now.
    * creates or updates contexts in LaunchDarkly, which makes them available for targeting and autocomplete on the dashboard.
    *
    * @user A struct containing at least a "key" key to uniquely identify the context
    */
    function identifyUser(
        struct user={}
    ) {
        identifyContext( user );
    }

    /**
    * Get's the status of the SDK's data store
    *
    * @returns A struct with the keys isAvailable, isRefreshNeeded, and detail
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
    * @returns A struct with the keys isAvailable, isRefreshNeeded, and detail
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
    * Tracks that a context performed an event.
    *
    * @eventName the name of the event
    * @context A struct containing at least a "key" key to uniquely identify the context
    * @data additional data associated with the event.  Can be simple or complex values
    * @metricValue a numeric value used by the LaunchDarkly experimentation feature in numeric custom metrics. Can be omitted if this event is used by only non-numeric metrics. This field will also be returned as part of the custom event for Data Export.
    */
    function track(
        required string eventName,
        any context={},
        any data,
        numeric metricValue
    ) {
        arguments.context = arguments.user ?: arguments.context;
        context = buildLDContext( context );
        if( !isNull( data ) && !isJSON( data ) ) {
            data = LDValue.parse( serializeJSON( data ) );
        }

        if( !isNull( metricValue ) ) {
            getLDClient()
                .trackMetric(
                    javaCast( 'string', eventName ),
                    context,
                    ( isNull( data ) ? javaCast( 'null', '' ) : data ),
                    javaCast( 'double', metricValue )
                );
        } else if( !isNull( data ) ) {
            getLDClient()
                .trackData(
                    javaCast( 'string', eventName ),
                    context,
                    data
                );
        } else {
            getLDClient()
                .track(
                    javaCast( 'string', eventName ),
                    context
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
    * The listener will be notified whenever the SDK receives any change to any feature flag's configuration, or to a context segment that is referenced by a feature flag.
    * If the updated flag is used as a prerequisite for other flags, the SDK assumes that those flags may now behave differently and sends flag change events for them as well.
    *
    * Note that this does not necessarily mean the flag's value has changed for any particular context, only that some part of the flag configuration was changed so that
    * it may return a different value than it previously returned for some context.
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
    * Registers a listener to be notified of a change in a specific feature flag's value for a specific set of context properties.
    * When you call this method, it first immediately evaluates the feature flag. It then uses a flag change listener to start listening for feature
    * flag configuration changes, and whenever the specified feature flag changes, it re-evaluates the flag for the same context.
    * It then calls your FlagValueChangeListener if and only if the resulting value has changed.
    *
    * @featureKey Name of the feature key you'd like to monitor
    * @udf A closure which will be called any time a flag value changes for a given context and featureKey.  The closure will receive two args-- the old value and new value
    * @context A struct containing at least a "key" key to uniquely identify the context
    *
    */
    function registerFlagValueChangeListener(
        required string featureKey,
        required udf,
        any context={}
    ) {
        arguments.context = arguments.user ?: arguments.context;
        return getLDClient()
            .getFlagTracker()
            .addFlagValueChangeListener(
                javaCast( 'string', featureKey ),
                buildLDContext( context ),
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

    /**+
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
        setTestData( javaCast( 'null', '' ) );
    }

}
