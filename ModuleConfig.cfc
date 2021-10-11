component {

    function configure() {
        settings = {
            SDKKey='',
            diagnosticOptOut=false,
            startWaitms=5000,
            offline=false,
            http={},
            logging={},
            userProvider=()=>{ return {}; }
        };
    }

}