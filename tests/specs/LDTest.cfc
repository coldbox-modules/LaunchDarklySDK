/**
* This tests the BDD functionality in TestBox. This is CF10+, Lucee4.5+
*/
component extends="testbox.system.BaseSpec"{

	SDKKey = server.system.environment.SDKKey ?: '';

	function beforeAll() {
		LD = new models.LD( {
			SDKKey=SDKKey,
			userProvider=()=>{ return { "Key" : "brad" }; }
		} );
	}

	function afterAll() {
		if( !isNull( LD ) ) {
			LD.shutdown()
		}
	}

	function run(){

		describe( "LD Client", function(){

			it("can fetch a string variation", ()=>{
				expect( LD.stringVariation( 'string-feature', 'esfsdf' ) ).toBe( 'bar' );
			});

			it("can fetch a boolean variation", ()=>{
				expect( LD.booleanVariation( 'boolean-feature', false ) ).toBeFalse();
				expect( LD.variation( 'boolean-feature', false ) ).toBeFalse();
			});

			it("can fetch a number variation", ()=>{
				expect( LD.numberVariation( 'number-feature', 23  ) ).toBe( 1 );
			});

			it("can fetch a json variation", ()=>{
				expect( LD.JSONVariation( 'json-feature', [] ) ).toBe( { "foo": "bar" } );
				expect( LD.JSONVariation( 'json-feature', "[]" ) ).toBe( { "foo": "bar" } );
			});

			it("can fetch a string detail variation", ()=>{
				var result = LD.stringVariationDetail( 'string-feature', 'esfsdf' );
				expect( result ).toBeStruct();
				expect( result.value ).toBe( 'bar' );
			});

			it("can fetch a boolean detail variation", ()=>{
				var result = LD.booleanVariationDetail( 'boolean-feature', false );
				expect( result ).toBeStruct();
				expect( result.value ).toBeFalse();

				var result = LD.variationDetail( 'boolean-feature', false );
				expect( result ).toBeStruct();
				expect( result.value ).toBeFalse();
			});

			it("can fetch a number detail variation", ()=>{
				var result = LD.numberVariationDetail( 'number-feature', 23  );
				expect( result ).toBeStruct();
				expect( result.value ).toBe( 1 );
			});

			it("can fetch a json detail variation", ()=>{
				var result = LD.JSONVariationDetail( 'json-feature', [] );
				expect( result ).toBeStruct();
				expect( result.value ).toBe( { "foo": "bar" } );
				var result = LD.JSONVariationDetail( 'json-feature', "[]" );
				expect( result.value ).toBe( { "foo": "bar" } );
			});

			it("can fetch all flags", ()=>{
				var result = LD.getAllFlags();
				expect( result ).toBeStruct();
				expect( result ).toHaveKey( 'isValid' );
				expect( result ).toHaveKey( 'flags' );
				expect( result.flags[ 'string-feature' ] ).toBeString();
			});

			it("can fetch all flags with reasons", ()=>{
				var result = LD.getAllFlags( withReasons=true );
				expect( result ).toBeStruct();
				expect( result ).toHaveKey( 'isValid' );
				expect( result ).toHaveKey( 'flags' );
				expect( result.flags[ 'string-feature' ] ).toBeStruct();
				expect( result.flags[ 'string-feature' ] ).toHaveKey( 'reason' );
				expect( result.flags[ 'string-feature' ] ).toHaveKey( 'value' );
				expect( result.flags[ 'string-feature' ].value ).toBeString();
			});

			it("can identiy a user", ()=>{
				LD.identifyUser( { key:'Luis' } );
			});

			it("can check the status of the SDK data store", ()=>{
				var result = LD.getDataStoreStatus();
				expect( result ).toBeStruct();
				expect( result ).toHaveKey( 'detail' );
				expect( result ).toHaveKey( 'isAvailable' );
				expect( result ).toHaveKey( 'isRefreshNeeded' );
			});

			it("can check the status of the SDK data source", ()=>{
				var result = LD.getDataSourceStatus();
				expect( result ).toBeStruct();
				expect( result ).toHaveKey( 'detail' );
				expect( result ).toHaveKey( 'lastError' );
				expect( result ).toHaveKey( 'state' );
				expect( result ).toHaveKey( 'stateSince' );
			});

			it("can track event", ()=>{
				LD.track( 'Logged in' );
			});

			it("can track event with data", ()=>{
				LD.track( eventName='invalid etries', data={ invalidItems : [ 'item 1', 'item 2' ] } );
			});

			it("can track event with metric value", ()=>{
				LD.track( eventName='invalid entries', metricValue=42 );
			});

			it("can track event with data and metric value", ()=>{
				LD.track( eventName='invalid entries', data={ invalidItems : [ 'item 1', 'item 2' ] }, metricValue=42 );
			});

			it("can recognize real flag", ()=>{
				expect( LD.isFlagKnown( 'string-feature' ) ).toBeTrue();
			});

			it("can not recognize fake flag", ()=>{
				expect( LD.isFlagKnown( 'foo-bar-123' ) ).toBeFalse();
			});

			it("can know if it is offline", ()=>{
				expect( LD.isOffline() ).toBeFalse();
			});

			it("can add a Flag Change Listener", ()=>{
				LD.registerFlagChangeListener( ( featureKey )=>writeDump( var="Flag [#featureKey#] changed!", output='console' ) );
			});

			it("can add a Flag value Change Listener", ()=>{
				LD.registerFlagValueChangeListener(
					'test',
					( oldvalue, newValue )=>writeDump( var="Flag [test] changed from [#oldValue#] to [#newValue#]!", output='console' )
				);
			});

		});


	}

}
