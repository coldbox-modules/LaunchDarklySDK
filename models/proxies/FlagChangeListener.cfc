/**
 * Functional interface that maps to com.launchdarkly.sdk.server.interfaces.FlagChangeListener
 * See https://launchdarkly.github.io/java-server-sdk/com/launchdarkly/sdk/server/interfaces/FlagChangeListener.html
 */
component extends="BaseProxy"{

    /**
     * Constructor
     *
     * @f Target lambda or closure
     */
    function init( required f ){
		super.init( arguments.f );
        return this;
    }

    /**
     * The SDK calls this method when a feature flag's configuration has changed in some way.
     */
    function onFlagChange( FlagChangeEvent ){
		loadContext();
		try {
  			return variables.target( arguments.FlagChangeEvent.getKey() );
        } finally {
        	unLoadContext();
        }
    }

}