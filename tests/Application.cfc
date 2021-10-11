/**
* Copyright Since 2005 Ortus Solutions, Corp
* www.ortussolutions.com
**************************************************************************************
*/
component{
	this.name = "A TestBox Runner Suite";
	// any other application.cfc stuff goes below:
	this.sessionManagement = true;

	// any mappings go here, we create one that points to the root called test.
	this.mappings[ "/tests" ] = getDirectoryFromPath( getCurrentTemplatePath() );
	this.mappings[ "/root" ] = getCanonicalPath( this.mappings[ "/tests" ] & '/../' );


	this.javaSettings = {
		loadPaths = directorylist( expandPath( '/lib' ), true, 'array', '*jar' ),
		loadColdFusionClassPath = true,
		reloadOnChange = false
	};
	
	// request start
	public boolean function onRequestStart( String targetPage ){

		return true;
	}
}