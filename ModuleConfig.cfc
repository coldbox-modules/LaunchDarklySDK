component {

    function configure() {
        // All default settings externalized into this CFC for non-ColdBox reuse
        settings = new models.config.Settings().configure();
    }

	/**
	* Fired when the module is unloaded
	*/
	function onUnload(){
		wirebox.getInstance( "LD@LaunchDarklySDK" ).shutdown();
	}


}