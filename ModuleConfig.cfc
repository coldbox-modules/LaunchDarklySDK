component {

    function configure() {
        settings = {
            SDKKey='',
            diagnosticOptOut=false,
            startWaitms=5000,
            offline=false,
            http={},
            logging={},
            userProvider=()=>{ return {}; },
            flagChangeListener='',
            // flagChangeListener=( featureKey )=>writeDump( var="Flag [#featureKey#] changed!", output='console' );
            flagValueChangeListeners=[
                /*
                {
                    featureKey : 'my-feature',
                    user : { key : 12345 },
                    udf : ( oldValue, newValue )=>writeDump( var="Flag [test] changed from [#oldValue#] to [#newValue#]!", output='console' )
                },
                {
                    featureKey : 'another-feature',
                    udf : ( oldValue, newValue )=>{}
                }
                */
            ]
        };
    }

	/**
	* Fired when the module is unloaded
	*/
	function onUnload(){
		wirebox.getInstance( "LD@LaunchDarklySDK" ).shutdown();
	}


}