/**
* This tests the BDD functionality in TestBox. This is CF10+, Lucee4.5+
*/
component extends="testbox.system.BaseSpec"{

	function beforeAll() {
		LD = new models.LD( {
			SDKKey=getSystemSetting( 'SDKKey', '' ),
			userProvider=function(){ return { "Key" : "brad" }; },
			datasource:{
				type : 'fileData',
				fileDataPaths : expandPath( '/tests/data/test-flags.json' ),
				fileDataAutoUpdate : true
			} 
		} );
	}

	function afterAll() {
		if( !isNull( LD ) ) {
			LD.shutdown();
		}
	}

	function run(){

		describe( "LD Client", function(){

			it("can fetch a string variation", function(){
				//var td = LD.getTestData()
				//td.update( td.flag( 'string-feature' ).variations( [ LD.getLDValue().of( 'bar' ) ] ).fallthroughVariation(0) )
				expect( LD.stringVariation( 'string-feature', 'esfsdf' ) ).toBe( 'bar' );
			});

			it("can fetch a boolean variation", function(){
				expect( LD.booleanVariation( 'boolean-feature', false ) ).toBeFalse();
				expect( LD.variation( 'boolean-feature', false ) ).toBeFalse();
			});

			it("can fetch a number variation", function(){
				expect( LD.numberVariation( 'number-feature', 23  ) ).toBe( 1 );
				expect( LD.variation( 'number-feature', 23  ) ).toBe( 1 );
			});

			it("can fetch a json variation", function(){
				expect( LD.JSONVariation( 'json-feature', [] ) ).toBe( { "foo": "bar" } );
				expect( LD.JSONVariation( 'json-feature', "[]" ) ).toBe( { "foo": "bar" } );
				expect( LD.variation( 'json-feature', [] ) ).toBe( { "foo": "bar" } );
				expect( LD.variation( 'json-feature', "[]" ) ).toBe( { "foo": "bar" } );
			});

			it("can fetch a string detail variation", function(){
				var result = LD.stringVariationDetail( 'string-feature', 'esfsdf' );
				expect( result ).toBeStruct();
				expect( result.value ).toBe( 'bar' );
				var result = LD.variationDetail( 'string-feature', 'esfsdf' );
				expect( result ).toBeStruct();
				expect( result.value ).toBe( 'bar' );
			});

			it("can fetch a boolean detail variation", function(){
				var result = LD.booleanVariationDetail( 'boolean-feature', false );
				expect( result ).toBeStruct();
				expect( result.value ).toBeFalse();

				var result = LD.variationDetail( 'boolean-feature', false );
				expect( result ).toBeStruct();
				expect( result.value ).toBeFalse();
			});

			it("can fetch a number detail variation", function(){
				var result = LD.numberVariationDetail( 'number-feature', 23  );
				expect( result ).toBeStruct();
				expect( result.value ).toBe( 1 );

				var result = LD.variationDetail( 'number-feature', 23  );
				expect( result ).toBeStruct();
				expect( result.value ).toBe( 1 );
			});

			it("can fetch a json detail variation", function(){
				var result = LD.JSONVariationDetail( 'json-feature', [] );
				expect( result ).toBeStruct();
				expect( result.value ).toBe( { "foo": "bar" } );
				
				var result = LD.JSONVariationDetail( 'json-feature', "[]" );
				expect( result.value ).toBe( { "foo": "bar" } );

				var result = LD.variationDetail( 'json-feature', [] );
				expect( result ).toBeStruct();
				expect( result.value ).toBe( { "foo": "bar" } );
				
				var result = LD.variationDetail( 'json-feature', "[]" );
				expect( result.value ).toBe( { "foo": "bar" } );
			});

			it("can fetch all flags", function(){
				var result = LD.getAllFlags();
				expect( result ).toBeStruct();
				expect( result ).toHaveKey( 'isValid' );
				expect( result ).toHaveKey( 'flags' );
				expect( result.flags[ 'string-feature' ] ).toBeString();
			});

			it("can fetch all flags with reasons", function(){
				var result = LD.getAllFlags( withReasons=true );
				expect( result ).toBeStruct();
				expect( result ).toHaveKey( 'isValid' );
				expect( result ).toHaveKey( 'flags' );
				expect( result.flags[ 'string-feature' ] ).toBeStruct();
				expect( result.flags[ 'string-feature' ] ).toHaveKey( 'reason' );
				expect( result.flags[ 'string-feature' ] ).toHaveKey( 'value' );
				expect( result.flags[ 'string-feature' ].value ).toBeString();
			});

			it("can identiy a user", function(){
				LD.identifyUser( { key:'Luis' } );
			});

			it("can check the status of the SDK data store", function(){
				var result = LD.getDataStoreStatus();
				expect( result ).toBeStruct();
				expect( result ).toHaveKey( 'detail' );
				expect( result ).toHaveKey( 'isAvailable' );
				expect( result ).toHaveKey( 'isRefreshNeeded' );
			});

			it("can check the status of the SDK data source", function(){
				var result = LD.getDataSourceStatus();
				expect( result ).toBeStruct();
				expect( result ).toHaveKey( 'detail' );
				expect( result ).toHaveKey( 'lastError' );
				expect( result ).toHaveKey( 'state' );
				expect( result ).toHaveKey( 'stateSince' );
			});

			it("can track event", function(){
				LD.track( 'Logged in' );
			});

			it("can track event with data", function(){
				LD.track( eventName='invalid entries', data={ invalidItems : [ 'item 1', 'item 2' ] } );
			});

			it("can track event with metric value", function(){
				LD.track( eventName='invalid entries', metricValue=42 );
			});

			it("can track event with data and metric value", function(){
				LD.track( eventName='invalid entries', data={ invalidItems : [ 'item 1', 'item 2' ] }, metricValue=42 );
			});

			it("can recognize real flag", function(){
				expect( LD.isFlagKnown( 'string-feature' ) ).toBeTrue();
			});

			it("can not recognize fake flag", function(){
				expect( LD.isFlagKnown( 'foo-bar-123' ) ).toBeFalse();
			});

			it("can know if it is offline", function(){
				expect( LD.isOffline() ).toBeFalse();
			});

			it("can add a Flag Change Listener", function(){
				LD.registerFlagChangeListener( function( featureKey ) {
					writeDump( var="Flag [#featureKey#] changed!", output='console' );
				 } );
			});

			it("can add a Flag value Change Listener", function(){
				LD.registerFlagValueChangeListener(
					'string-feature',
					function( oldvalue, newValue ) {
						writeDump( var="Flag [string-feature] changed from [#oldValue#] to [#newValue#]!", output='console' );
					}
				);
			});

			it("can track custom user info", function(){
				LD.identifyUser( {
					key : 'custom-user-info',
					'foo' : 'bar',
					'baz' : [ 1,2,3 ],
					'bum' : {
						'why' : 'not?',
						'nest' : [ 'me', 'here' ],
						'also' : {
							'this' : 'one',
							'as' : 'well'
						}
					}
				} );
				
			});

		});

	}

	function getSystemSetting( required key, defaultValue ){
		var value = getJavaSystem().getProperty( arguments.key );
		if ( !isNull( local.value ) ) {
			return value;
		}

		value = getJavaSystem().getEnv( arguments.key );
		if ( !isNull( local.value ) ) {
			return value;
		}

		if ( !isNull( arguments.defaultValue ) ) {
			return arguments.defaultValue;
		}

		throw(
			type   : "SystemSettingNotFound",
			message: "Could not find a Java System property or Env setting with key [#arguments.key#]."
		);
	}

	function getJavaSystem(){
		if ( !structKeyExists( variables, "javaSystem" ) ) {
			variables.javaSystem = createObject( "java", "java.lang.System" );
		}
		return variables.javaSystem;
	}
}
