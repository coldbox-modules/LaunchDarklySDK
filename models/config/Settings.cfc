component {

    function configure() {
        return {
            SDKKey : '',
            diagnosticOptOut : false,
            startWaitms : 5000,
            offline : false,
            http : {},
            logging : {},
            dataSource : {
                // Possible options: default, fileData, testData
                type : 'default',
                fileDataPaths : [],
                fileDataIgnoreDuplicates : true,
                fileDataAutoUpdate : false
            },
            userProvider : function(){ return {}; },
            flagChangeListener : '',
            // flagChangeListener : ( featureKey )=>writeDump( var="Flag [#featureKey#] changed!", output='console' );
            flagValueChangeListeners : [
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

}