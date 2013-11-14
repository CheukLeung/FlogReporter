
#ifndef OMCSF_TE_LOG_SIG
#define OMCSF_TE_LOG_SIG


#include "cello_cdefs_sigbase.h"  /* Signal bases                      */
#if 0
#include "cello_te_handlers.h"    /* Internal T & E handlers           */
#include "cello_te_group.h"       /* Internal trace group declarations */
#include "cello_trace.h"          /* RTOSI Trace Services              */
#endif



/*
** Define a suitable signal base
*/ 
#define OMCSF_LOG_SIGBASE               (OMCSF_SIGBASE + 50)

#define OMCSF_LOG_MAX_DATA_LEN          512   /* Max len of log data        */
#define OMCSF_LOG_MAX_FREEZE_STRING_LEN 64    /* Max len of a freeze string */


/*
** Typedefs
*/

/*
** String type for freeze strings
*/
typedef char OMCSF_freezeStrA[OMCSF_LOG_MAX_FREEZE_STRING_LEN];


/*
** The actual data that are stored in the Trace & Error Log. All
** strings are stored in data delimited with a null character. The
** position of the message, the process name, the file name and the
** binary data are all  indicated by its position parameter. If no
** binary data is stored, the variable binDataLen should be set to zero.
*/
struct OMCSF_logDataS
{
  U32             absTimeSec;  /* The absolute time stamp in seconds        */
  U32             absTimeTick; /* The tick corresponding to absolute time   */
  U16             lineNo;      /* Line number from where log is performed   */
  U16             fileNamePos; /* Name pos of file where log is performed   */
  U16             procNamePos; /* Name pos of process generating log entry  */
  U16             msgPos;      /* Position in data of the logged message    */
  U16             binDataPos;  /* Pos in data where binary data is stored   */
  U16             binDataLen;  /* The length of the binary data in data     */
  U32    group;       /* Trace group this log entry belongs to     */
  U8              data[OMCSF_LOG_MAX_DATA_LEN];  /* The actual logged data  */
};

#define OMCSF_LOG_DATA_SIZE(SIZE)  \
        (sizeof(struct OMCSF_logDataS) + \
	 sizeof(U8) * ((SIZE) - OMCSF_LOG_MAX_DATA_LEN))


/*
**   Constants
*/


/* >   Signal: OMCSF_LOG_HUNT_IND
**
** Description:
**   This signal is used for hunting the T & E Log process.
**
** Field description:
**   sigNo  The signal number
*/

#define OMCSF_LOG_HUNT_IND (OMCSF_LOG_SIGBASE + 0)
/* !- SIGNO(struct OMCSF_logHuntIndS) -! */
 
struct OMCSF_logHuntIndS
{
  SIGSELECT sigNo;
};


/* >   Signal: OMCSF_LOG_TIME_UPDATE_IND
**
** Description:
**   This signal is used as a timeot signal to indicate that
**   the absolut time stamp in Trace & Error Log process shall
**   be updated.
**
*/

#define OMCSF_LOG_TIME_UPDATE_IND (OMCSF_LOG_SIGBASE + 1)


/* >   Signal: OMCSF_LOG_WRITE_IND
**
** Description:
**   Write one entry into the log. Together with the log data are
**   the name of the current process, file name and source line
**   number stored.
**
** Pre-conditions:
**   None.
**
** Post-conditions:
**   If the log is not freezed, the message is logged.
**
** Field description:
**   sigNo       The signal number.
**   logDataSize The size of the actual data to be logged.
**   logData     The actual data to be logged.
*/

#define OMCSF_LOG_WRITE_IND (OMCSF_LOG_SIGBASE + 2)
/* !- SIGNO(struct OMCSF_logWriteIndS) -! */

struct OMCSF_logWriteIndS
{
  SIGSELECT             sigNo;
  U16                   logDataSize;
  struct OMCSF_logDataS logData;
};

#define OMCSF_LOG_WRITE_IND_SIZE(SIZE)  \
        (sizeof(struct OMCSF_logWriteIndS) + \
	 sizeof(U8) * ((SIZE) - OMCSF_LOG_MAX_DATA_LEN))


/* >   Signal: OMCSF_LOG_MONITOR_CONNECT_REQ
**
** Description:
**   This signal is used by the monitor to request a connection
**   to the T & E log process.
**
** Field description:
**   sigNo   The signal number
*/

#define OMCSF_LOG_MONITOR_CONNECT_REQ (OMCSF_LOG_SIGBASE + 3) /* !- SIGNO(struct OMCSF_logMonitorConnectReqS) -! */
 
struct OMCSF_logMonitorConnectReqS
{
  SIGSELECT sigNo;
};


/* >   Signal: OMCSF_LOG_MONITOR_CONNECT_CFM
**
** Description:
**   A confirmation to a OMCSF_LOG_MONITOR_CONNECT_REQ.
**
** Field description:
**   sigNo       The signal number
**   result      If the connection succeded or not. If the connect
**               was rejected then it means that another monitor
**               has already connected.
**   tickLength  Which tick length in microseconds does the Trace &
**               Error Log use?
*/

#define OMCSF_LOG_MONITOR_CONNECT_CFM (OMCSF_LOG_SIGBASE + 4) /* !- SIGNO(struct OMCSF_logMonitorConnectCfmS) -! */
 
struct OMCSF_logMonitorConnectCfmS
{
  SIGSELECT    sigNo;
  U8      result;
  unsigned int tickLength;
};


/* >   Signal: OMCSF_LOG_MONITOR_ATTACH_IND
**
** Description:
**   This signal is used by T & E log process to attach to the
**   monitor whenever it has connected.
**
** Field description:
**   sigNo   The signal number
*/

#define OMCSF_LOG_MONITOR_ATTACH_IND (OMCSF_LOG_SIGBASE + 5)
/* !- SIGNO(struct OMCSF_logMonitorAttachIndS) -! */
 
struct OMCSF_logMonitorAttachIndS
{
  SIGSELECT sigNo;
};


/* >   Signal: OMCSF_LOG_MONITOR_IND
**
** Description:
**   This signal is used as a monitor indication, i.e. a result
**   of OMCSF_LOG_WRITE_IND, and is sent to the monitor.
**
** Field description:
**   sigNo         The signal number
**   acknowledge   Should this monitor indication be acknowledged?
**                 Used for not overflowing the monitor and any link
**                 handlers in between.
**   logged        Has the log data actually been logged or not? When
**                 the log is disabled no logging is performed, even
**                 though we still generate monitor indications.
**   relTimeStamp  The relative time stamp for this log record.
**   logData       The actual log data for this log record.
*/

#define OMCSF_LOG_MONITOR_IND (OMCSF_LOG_SIGBASE + 6)
/* !- SIGNO(struct OMCSF_logMonitorIndS) -! */
 
struct OMCSF_logMonitorIndS
{
  SIGSELECT             sigNo;
  U8               acknowledge;
  U8               logged;
  struct Cs_traceTStamp relTimeStamp;
  struct OMCSF_logDataS logData;
};

#define OMCSF_LOG_MONITOR_IND_SIZE(SIZE) \
        (sizeof(struct OMCSF_logMonitorIndS) +\
	 SIZE - sizeof(struct OMCSF_logDataS))


/* >   Signal: OMCSF_LOG_MONITOR_ACK_IND
**
** Description:
**   This signal is used by the monitor to acknowledge a received
**   log write indication that has been marked to be acknowledged.
**
** Field description:
**   sigNo  The signal number
*/

#define OMCSF_LOG_MONITOR_ACK_IND (OMCSF_LOG_SIGBASE + 7)
/* !- SIGNO(struct OMCSF_logMonitorAckIndS) -! */
 
struct OMCSF_logMonitorAckIndS
{
  SIGSELECT sigNo;
};


/* >   Signal: OMCSF_LOG_MONITOR_ACK_TMO_IND
**
** Description:
**   This signal is used by the T & E log to supervise
**   that the monitor acknowledge signal is received
**   within a specifed timeout.
**
*/

#define OMCSF_LOG_MONITOR_ACK_TMO_IND (OMCSF_LOG_SIGBASE + 8)
 

/* >   Signal: OMCSF_LOG_READ_REQ
**
** Description:
**   This signal is used for requesting a read of the Trace & Error Log.
**
** Field description:
**   sigNo       The signal number
**   oldestTime  How old, in seconds, log entries to we want? Specify -1
**               if the log read shall start with the oldest log entry .
**   monitor     Shall the log be dumped to the monitor?
*/

#define OMCSF_LOG_READ_REQ (OMCSF_LOG_SIGBASE + 9)
/* !- SIGNO(struct OMCSF_logReadReqS) -! */
 
struct OMCSF_logReadReqS
{
  SIGSELECT sigNo;
  int       oldestTime;
  U8   monitor;
};


/* >   Signal: OMCSF_LOG_READ_CFM
**
** Description:
**   A confirmation to a OMCSF_LOG_READ_REQ signal.
**
** Field description:
**   sigNo   The signal number
**   result  The result of the read request
*/

#define OMCSF_LOG_READ_CFM (OMCSF_LOG_SIGBASE + 10)
/* !- SIGNO(struct OMCSF_logReadCfmS) -! */
 
struct OMCSF_logReadCfmS
{
  SIGSELECT            sigNo;
  U32 result;
};


/* >   Signal: OMCSF_LOG_READ_ATTACH_IND
**
** Description:
**   This signal is used by T & E log process to attach to the
**   log receiver whenever a OMCSF_LOG_READ_REQ has been received.
**
** Field description:
**   sigNo   The signal number
*/

#define OMCSF_LOG_READ_ATTACH_IND (OMCSF_LOG_SIGBASE + 11)
/* !- SIGNO(struct OMCSF_logReadAttachIndS) -! */
 
struct OMCSF_logReadAttachIndS
{
  SIGSELECT sigNo;
};


/* >   Signal: OMCSF_LOG_READ_IND
**
** Description:
**   A log read indication as a result of OMCSF_LOG_READ_REQ.
**   The OMCSF_LOG_READ_IND is repeated for each log record
**   requested from the Trace & Error Log.
**
** Field description:
**   sigNo         The signal number
**   acknowledge   Should this log read indication be acknowledged?
**                 Used for not overflowing the log reader and any link
**                 handlers in between.
**   tickLength    Which tick length in microseconds does the Trace &
**                 Error Log use? It is really unnecessary to send this
**                 information for *every* log record, but it was the
**                 easiest way to to it.
**   relTimeStamp  The relative time stamp for this log record.
**   logData       The actual log data for this log record.
*/

#define OMCSF_LOG_READ_IND (OMCSF_LOG_SIGBASE + 12)
/* !- SIGNO(struct OMCSF_logReadIndS) -! */
 
struct OMCSF_logReadIndS
{
  SIGSELECT             sigNo;
  U8               acknowledge;
  unsigned int          tickLength;
  struct Cs_traceTStamp relTimeStamp;
  struct OMCSF_logDataS logData;
};

#define OMCSF_LOG_READ_IND_SIZE(SIZE) \
        (sizeof(struct OMCSF_logReadIndS) +\
	 SIZE - sizeof(struct OMCSF_logDataS))


/* >   Signal: OMCSF_LOG_READ_ACK_IND
**
** Description:
**   This signal is used by the log reader to acknowledge a received
**   log read indication that has been marked to be acknowledged.
**
** Field description:
**   sigNo  The signal number
*/

#define OMCSF_LOG_READ_ACK_IND (OMCSF_LOG_SIGBASE + 13) /* !- SIGNO(struct OMCSF_logReadAckIndS) -! */
 
struct OMCSF_logReadAckIndS
{
  SIGSELECT sigNo;
};


/* >   Signal: OMCSF_LOG_READ_ACK_TMO_IND
**
** Description:
**   This signal is used by the T & E log to supervise
**   that the log read acknowledge signal is received
**   within a specifed timeout.
**
*/

#define OMCSF_LOG_READ_ACK_TMO_IND (OMCSF_LOG_SIGBASE + 14)
 

/* >   Signal: OMCSF_LOG_READ_DUMP_IND
**
** Description:
**   This signal is used by the T & E log to inform the log read
**   requester about the progress of the log read operation when-
**   ever the log read requester the log dump receiver is not the
**   same process.
**
** Field description:
**   sigNo  The signal number
*/

#define OMCSF_LOG_READ_DUMP_IND (OMCSF_LOG_SIGBASE + 15)
/* !- SIGNO(struct OMCSF_logReadDumpIndS) -! */
 
struct OMCSF_logReadDumpIndS
{
  SIGSELECT sigNo;
};


/* >   Signal: OMCSF_LOG_FREEZE_REQ
**
** Description:
**   This signal is used for requesting a freeze of the Trace & Error
**   Log. The freeze can be specified instantly, or by specifying a
**   freeze string that has to be matched against a logged entry.
**   An additional count of how many log entries that shall be logged
**   after the freeze string has been matched can also be specified.
**
** Field description:
**   sigNo         The signal number
**   instantFreeze Shall we freeze the log instantly?
**   freezeCount   How many entries shall be logged after the freeze string
**                 has been matched. This member is only valid if the member
**                 instantFreeze is False.
**   groupMatch    Shall we match for a specific trace group when freezing?
**   freezeGroup   The trace group that shall be matched when freezing the
**                 log. This member is only valid if the member groupMatch
**                 is True and the member instantFreeze is False.
**   freezeString  The freeze string to match the entries that are logged.
**                 This member is only valid if the member instantFreeze
**                 is False.
*/

#define OMCSF_LOG_FREEZE_REQ (OMCSF_LOG_SIGBASE + 16)
/* !- SIGNO(struct OMCSF_logFreezeReqS) -! */
 
struct OMCSF_logFreezeReqS
{
  SIGSELECT        sigNo;
  U8          instantFreeze;
  int              freezeCount;
  U8          groupMatch;
  U32     freezeGroup;
  OMCSF_freezeStrA freezeString;
};


/* >   Signal: OMCSF_LOG_FREEZE_CFM
**
** Description:
**   A confirmation to a OMCSF_LOG_FREEZE_REQ signal.
**
** Field description:
**   sigNo   The signal number
**   result  The result of the freeze request
*/

#define OMCSF_LOG_FREEZE_CFM (OMCSF_LOG_SIGBASE + 17)
/* !- SIGNO(struct OMCSF_logFreezeCfmS) -! */
 
struct OMCSF_logFreezeCfmS
{
  SIGSELECT            sigNo;
  U32 result;
};


/* >   Signal: OMCSF_LOG_RESUME_REQ
**
** Description:
**   This signal is used for resuming the logging in the Trace & Error
**   Log. It also removes any pending freeze requests.
**
** Field description:
**   sigNo         The signal number
*/

#define OMCSF_LOG_RESUME_REQ (OMCSF_LOG_SIGBASE + 18)
/* !- SIGNO(struct OMCSF_logResumeReqS) -! */

struct OMCSF_logResumeReqS
{
  SIGSELECT sigNo;
};


/* >   Signal: OMCSF_LOG_RESUME_CFM
**
** Description:
**   A confirmation to a OMCSF_LOG_RESUME_REQ signal.
**
** Field description:
**   sigNo   The signal number
**   result  The result of the resume request
*/

#define OMCSF_LOG_RESUME_CFM (OMCSF_LOG_SIGBASE + 19)
/* !- SIGNO(struct OMCSF_logResumeCfmS) -! */
 
struct OMCSF_logResumeCfmS
{
  SIGSELECT            sigNo;
  U32 result;
};


/* >   Signal: OMCSF_LOG_CLEAR_REQ
**
** Description:
**   This signal is used for clearing the Trace & Error Log.
**
** Field description:
**   sigNo         The signal number
*/

#define OMCSF_LOG_CLEAR_REQ (OMCSF_LOG_SIGBASE + 20)
/* !- SIGNO(struct OMCSF_logClearReqS) -! */

struct OMCSF_logClearReqS
{
  SIGSELECT sigNo;
};


/* >   Signal: OMCSF_LOG_CLEAR_CFM
**
** Description:
**   A confirmation to a OMCSF_LOG_CLEAR_REQ signal.
**
** Field description:
**   sigNo   The signal number
**   result  The result of the clear request
*/

#define OMCSF_LOG_CLEAR_CFM (OMCSF_LOG_SIGBASE + 21)
/* !- SIGNO(struct OMCSF_logClearCfmS) -! */
 
struct OMCSF_logClearCfmS
{
  SIGSELECT            sigNo;
  U32 result;
};


/* >   Signal: OMCSF_LOG_MONITORING_STATE_REQ
**
** Description:
**   This signal is used changine the monitoring state of
**   the Trace & Error Log. Even though the monitor is
**   connected it is possible to enable and disable the
**   monitoring.
**
** Field description:
**   sigNo     The signal number
**   query     Is this a query for the current monitoring state?
**             If query it True then the value of disabled is ignored.
**   disable   Shall the monitor be disabled?
*/

#define OMCSF_LOG_MONITORING_STATE_REQ (OMCSF_LOG_SIGBASE + 22)
/* !- SIGNO(struct OMCSF_logMonitoringStateReqS) -! */

struct OMCSF_logMonitoringStateReqS
{
  SIGSELECT sigNo;
  U8   query;
  U8   disable;
};


/* >   Signal: OMCSF_LOG_MONITORING_STATE_CFM
**
** Description:
**   A confirmation to a OMCSF_LOG_MONITORING_STATE_REQ signal.
**
** Field description:
**   sigNo    The signal number
**   result   The result of the monitoring state request
**   disabled The current monitoring state.
*/

#define OMCSF_LOG_MONITORING_STATE_CFM (OMCSF_LOG_SIGBASE + 23)
/* !- SIGNO(struct OMCSF_logMonitoringStateCfmS) -! */
 
struct OMCSF_logMonitoringStateCfmS
{
  SIGSELECT            sigNo;
  U32 result;
  U8              disabled;
};


/* >   Signal: OMCSF_LOG_MONITOR_DISCONNECT_IND
**
** Description:
**   This signal is used by the monitor to indicate that
**   it has disconnected from the T & E log process. This
**   normally only used if the monitor process still wants
**   to keep on living, since the normal way to disconnect
**   is to die and thus generating an attach indication
**   instead. This is normally the case with the monitor
**   application on host. Other kind of monitors might
**   want another way of disconnecting themselves.
**
** Field description:
**   sigNo   The signal number
*/

#define OMCSF_LOG_MONITOR_DISCONN_IND (OMCSF_LOG_SIGBASE + 24)
/* !- SIGNO(struct OMCSF_logMonitorDisconnIndS) -! */
 
struct OMCSF_logMonitorDisconnIndS
{
  SIGSELECT sigNo;
};



#define OMCSF_MONITOR_SLIDING_WINDOW_IND (OMCSF_LOG_SIGBASE + 25)
/* !- SIGNO(struct OMCSF_monitorSlidingWindowIndS) -! */
 
struct OMCSF_monitorSlidingWindowIndS
{	
  SIGSELECT sigNo;	
  int size;	
};

#define DEFAULT_MONITOR_SLIDING_WINDOW_SIZE 20




/* >   End of double inclusion protection
**
*/


#ifdef __cplusplus
}
#endif

#endif /* OMCSF_TE_LOG_SIG */
