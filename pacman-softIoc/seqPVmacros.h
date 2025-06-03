/*================================================================
 *
 * seqPVmacros.h -- PV-related macros for EPICS State Notation Language 
 *    (SNL) code development
 *
 * 2011-Sep-06  [laznovsky@psi] added ef*() macros, changed pvSet()
 * 2009-Feb-03  [laznovsky@psi] changed to PV_NONE, PV_MON, PV_EF
 * 2008-Jul-18  [laznovsky@psi] all-upped PV_* macros, a la Simon Rees
 * 2008-Jun-13  [laznovsky@psi] new version for PSI
 * 2002-Mar-08  [lazmo@slac] added pvSet()
 * 2002-Feb-21  [lazmo@slac] fixed comments
 * 2001-Nov-24  [lazmo@slac] added PVA & PVAA
 * 2001-Oct-18  [lazmo@slac] original (seqPVmacros.h)
 *
 * Author:
 *   M. Laznovsky -- lazmo@slac.stanford.edu (3/2001-5/2008)
 *   M. Laznovsky -- laznovsky@psi.ch (5/2008-)
 *
 ****************************************************************
 * $Source: $
 * $Revision: $
 * $Date: $
 ****************************************************************
 */

/*----------------------------------------------------------------
 * PV() -- declare a variable and the EPICS PV it's assigned to, with
 * optional monitor & event flag.  One line takes the place of
 * the usual:
 *
 *    int blah;
 *    assign blah ...
 *    monitor blah;
 *    evflag blah_ef;
 *    sync blah ...
 *
 * Format:
 *
 *    PV( varType, varName, pvName, other );
 *
 * Arguments:
 *
 *    varType   int, short, float, etc.
 *    varName   variable name
 *    pvName    associated PV
 *    other     one of the following:
 *                  PV_NONE
 *                  PV_MON
 *                  PV_EF
 *
 * Examples:
 *
 *    PV (int,   gui_goo,   "{STN}:GUI:GOO",   PV_NONE);   // no monitor
 *    PV (float, gui_fudge, "{STN}:GUI:FUDGE", PV_MON);    // monitor
 *    PV (short, gui_run,   "{STN}:GUI:RUN",   PV_EF);     // monitor & event flag
 *
 *----------------------------------------------------------------
 */

#define PV(TYPE,VAR,PV,OTHER)	\
  TYPE    VAR;			\
  assign  VAR to PV		\
  OTHER  (VAR)

/*----------------------------------------------------------------
 * PVA(), for single waveform rec or array of PVs
 *
 *   "varName" becomes array of <varType>; 3rd arg is number of elements
 *
 * Examples:
 *
 *   single waveform record:
 *
 *     PVA (short, plot_x0,  32, "{STN}:DATA:PLOT:X0", PV_NONE);
 *  
 *   array of PVs:
 *
 *     #define PVA_zap {	\
 *         "{STN}:GUI:ZAP1",	\
 *         "{STN}:GUI:ZAP2",	\
 *         "{STN}:GUI:ZAP3"	\
 *       }
 *     PVA (int, zap, 3, PVA_zap, PV_EF);
 *
 *----------------------------------------------------------------
 */

#define PVA(TYPE,VAR,NELEM,PV,OTHER)	\
  TYPE    VAR [ NELEM ];		\
  assign  VAR to PV			\
  OTHER  (VAR)

/*----------------------------------------------------------------
 * PVAA(), for arrays of waveform records
 *
 *   "varName" becomes double-dimensioned array of <varType>
 *   3rd arg is number of waveform records
 *   4th arg is number of elements per record
 *   Need to define another macro first for "PV"
 *
 * Example:
 *
 *	#define PVAA_plotx {		\
 *	    "{STN}:DATA:PLOT:X1",	\
 *	    "{STN}:DATA:PLOT:X2",	\
 *	    "{STN}:DATA:PLOT:X3"	\
 *	  }
 *	PVAA (short, plotx, 3, 500, PVAA_plotx, PV_NONE);
 *
 *----------------------------------------------------------------
 */

#define PVAA(TYPE,VAR,NREC,NELEM,PV,MON)	\
  TYPE    VAR[NREC][NELEM];			\
  assign  VAR to PV				\
  MON    (VAR)

/*================================================================
 * macros for last arg of PV* ("MON")
 *================================================================
 */

/*--------------------------------
 * no monitor
 *--------------------------------
 */
#define PV_NONE(VAR)	/* this macro intentionally left blank :P */

/*--------------------------------
 * monitor
 *--------------------------------
 */
#define PV_MON(VAR) ; monitor VAR

/*--------------------------------
 * monitor & event flag; flag var will be named "<var>_ef"
 *--------------------------------
 */
#define PV_EF(VAR)	\
  PV_MON     (VAR);	\
  evflag      VAR##_ef;	\
  sync    VAR VAR##_ef

/*================================================================*/
/*================================================================*/

/*----------------------------------------------------------------
 * pvSet() -- variable assign and pvPut() in one
 *
 * Format:
 *
 *    pvSet( var, exp );
 *
 * Arguments:
 *
 *    var   variable name
 *    exp   expression
 *
 * Example:
 *
 *    pvSet (foo, xyz + 2);
 *      expands to:
 *        do {
 *          foo = xyz + 2;
 *          pvPut(foo);
 *        } while (0)
 *
 *----------------------------------------------------------------
 */

#define pvSet(VAR,EXP)	\
  {{			\
    VAR = (EXP);	\
    pvPut(VAR);		\
  }}			\

#if 0   /* snc doesn't do "do/while"... yet? */
  do {			\
    VAR = (EXP);	\
    pvPut(VAR);		\
  } while (0)
#endif

/*----------------------------------------------------------------
 * pvSetStr() ... string version
 *----------------------------------------------------------------
 */

#define pvSetStr(VAR,STR)	\
  {{			\
    strcpy(VAR,STR);	\
    pvPut(VAR);		\
  }}			\

/*================================================================*/

/* ef macros... add "_ef" to end of name
 */
#define efTAC(V) efTestAndClear (V##_ef)
#define efClr(V) efClear        (V##_ef)

/*================================================================*/
/*================================================================*/

/* end */
