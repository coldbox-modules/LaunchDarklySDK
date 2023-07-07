component {

    function configure() {
        return {
            SDKKey : '',
            diagnosticOptOut : false,
            startWaitms : 5000,
            offline : false,
            contextExplodeStructAttributes : false,
            http : {},
            logging : {},
            dataSource : {
                // Possible options: default, fileData, testData
                type : 'default',
                fileDataPaths : [],
                fileDataIgnoreDuplicates : true,
                fileDataAutoUpdate : false
            },
            contextProvider : defaultContextProvider,
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

    // Avoiding a closure by default to work around a silly Adobe ColdFusion 2016 bug
    function defaultContextProvider(){
        return {};
    }

}