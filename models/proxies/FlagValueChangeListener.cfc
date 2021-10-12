/**
 * Functional interface that maps to com.launchdarkly.sdk.server.interfaces.FlagValueChangeListener
 * See https://launchdarkly.github.io/java-server-sdk/com/launchdarkly/sdk/server/interfaces/FlagValueChangeListener.html
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
     * The SDK calls this method when a feature flag's value has changed with regard to the specified user.
     */
    function onFlagValueChange( FlagValueChangeEvent ){
		loadContext();
		try {
            return variables.target(
                // old and new value are returned as LDValue instance
                // https://launchdarkly.github.io/java-server-sdk/com/launchdarkly/sdk/LDValue.html
                deserializeJSON( arguments.FlagValueChangeEvent.getOldValue().toJsonString() ),
                deserializeJSON( arguments.FlagValueChangeEvent.getNewValue().toJsonString() )                     
            );
        } finally {
        	unLoadContext();
        }
    }

}