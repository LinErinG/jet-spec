;+
; Project     : Sophie/Lindsay jet project
;
; Name        : JET_MAKE_SPEX
;
; Purpose     : Produce RHESSI spectrum and response files for a jet event of interest.
;				This routine is meant to be used in partnership with JET_FIT_SPEX.
;				Keywords should be matched between these two routines.
;
; Syntax      : jet_make_spex, flare_num
;
; Inputs      : FLARE_NUM = RHESSI flare list identifier for this flare
;
; Outputs     : NONE, but spectrum and response files are written with auto-naming.
;				Auto-naming is 'hsi_spec_FLARENUM.fits' and 'hsi_srm_FLARENUM.fits'
;				A plot showing the selected time intervals for fitting and background
;				is also saved in PNG format (time_interval_FLARENUM.png).
;
; Keywords    : DELTA_T = 	Duration of time interval chosen for fitting
;						  	The interval is symmetric around the flare peak listed in the 
;							RHESSI flare list.  Default is 30 seconds.
;				TIME_RANGE=	Explicit time range for fitting set by user.  This overrides 
;							DELTA_T.  If neither DELTA_T nor TIME_RANGE is set, then 
;							30 seconds around the flare peak will be used.
;				BKG_TIME_RANGE = Explicit background time range for fitting set by user.
;							If this variable is not set, then the nearest 4-minute eclipse 
;							interval is located and selected.
;				DET_MASK =	Array indicating which RHESSI detector (front segments) 
;							to use.  Default is Detector 1 only.
;				DIR_PNG =	output directory in which to store the lightcurve PNGs.
;						  	If directory does not exists, it is created.  If no directory 
;						  	is specified, the local directory is assumed.
;				DIR_FITS =	output directory in which to store the spectral FITS files.
;						  	If directory does not exists, it is created.  If no directory 
;						  	is specified, the local directory is assumed.
;			    STOP = 		keyword to stop procedure, for debugging
;
; Examples	  :
;
;	; Sept 12, 2012 (Example used for most of the debugging.  All default settings.)
;	flare_num = 12091214
;	jet_make_spex, flare_num
;	jet_fit_spex, flare_num
;	
; 	; June 30, 2012 (Example using the default of 30 sec around flare peak)
;	flare_num = 12063050
;	jet_make_spex, flare_num
;	jet_fit_spex, flare_num
;	Note: an examination of the defaults chosen here show that the default does NOT give 
;	the most optimal interval.  It's missing the high-energy component.
;	
; 	; June 30, 2012 (Example of manually setting a larger fit duration, still around the peak)
;	flare_num = 12063050
;	jet_make_spex, flare_num, delta_t=60.
;	jet_fit_spex, flare_num, delta_t=60.
;
; 	; June 30, 2012 (Example of manually setting the time interval)
;	flare_num = 12063050
;	jet_make_spex, flare_num, time_range='2012-jun-30 '+['1830','1832']
;	jet_fit_spex, flare_num, time_range='2012-jun-30 '+['1830','1832']
; 	; This is a much better time interval, and gives a good fit.
;
;
; History     : First version 2018 Oct 23, L. Glesener
;-

PRO	jet_make_spex, flare_num, delta_t=delta_t, time_range=time_range, $
				   bkg_time_range = bkg_time_range, $
				   det_mask=det_mask, dir_png=dir_png, dir_fits=dir_fits, stop=stop

	default, det_mask, [1,intarr(8)]	; Default detector is 1.
	det_mask = [det_mask, intarr(9)]	; Don't use rear segments.
	default, delta_t, 30.

	; Check if the output directories exist.  If not, create them.
	; If no out_dir is set then use current directory.
	if keyword_set( DIR_PNG ) then begin
		if file_search( DIR_PNG ) eq '' then spawn, 'mkdir '+dir_png
	endif else dir_png = './'
	if keyword_set( DIR_FITS ) then begin
		if file_search( DIR_FITS ) eq '' then spawn, 'mkdir '+dir_fits
	endif else dir_fits = './'

	; Retrieve the flare record and choose the time if one is not given.
	if not keyword_set( time_range ) then begin
		; Get a year range in which to look for the flare record.
		year = '200'+strmid(strtrim(flare_num,2),0,1)
		if year eq '2001' then year = '20'+strmid(strtrim(flare_num,2),0,2)
		time_year = year+['-jan-01','-dec-31']
		; Pull the flare list for that whole year.  (This could be made more efficient.)
		flare_list_obj =  hsi_flare_list(obs_time_interval =  anytim(time_year, /ecs))
		flare_list =  flare_list_obj -> getdata()
		; Find our flare and set the time range to DELTA_t around peak.
		flare = flare_list( where(flare_list.id_number eq flare_num) )
		time_range = flare.peak_time + [-0.5,0.5]*delta_t
		; Check to make sure we're not exceeding the flare times!
		if time_range[0] lt flare.start_time then time_range[0] = flare.start_time
		if time_range[1] gt flare.end_time then time_range[1] = flare.end_time
	endif
	;else begin
	;consider whether you still need the record if the time range is given.  Maybe no?
	;endelse

	; Display a plot of the surrounding time with our chosen 
	; interval indicated.
	obs_obj_wide = hsi_obs_summary()
	; Display and save the time profiles.
	obs_obj_wide-> set, obs_time_interval= anytim( time_range )+[-400,400]
	window, 1, xsi=600, ysi=600
	hsi_linecolors
	!p.multi=[0,1,2]
	obs_obj_wide-> plot, /ylog, dim1_colors=[1,2,3,4,5,6,7,8,9]
	outplot, anytim([time_range[0],time_range[0]],/yo),[1,1.e6]
	outplot, anytim([time_range[1],time_range[1]],/yo),[1,1.e6]

	; Now get the observing summary for our actual time of interest, 
	; to extract attenuator info.
	obs_obj = hsi_obs_summary()
	obs_obj-> set, obs_time_interval= anytim( time_range )

	; Attenuator state change times.  If there is an attenuator state change during the 
	; chosen time for analysis, then just return that information and quit.
	; This part has not been tested yet!
	flag_changes = obs_obj -> changes()
	if flag_changes.attenuator_state[0].start_times ne -1 then begin
		print, 'Attenuator state changes at:'
		for i=0, n_elements(flag_changes.attenuator_state)-1 do $
			ptim, flag_changes[i].attenuator_state.start_times
	endif

	; If no background time interval is specified, then find the nearest eclipse time.
	; THIS CODE SHOULD MIMIC EXACTLY WHAT IS IN JET_FIT_SPEX!

	if not keyword_set( bkg_time_range ) then begin
		; Our time range should not already include eclipses.  Widen it by 20 minutes on 
		; either side repeatedly until it does.
		wide_time = anytim( time_range )
		while( flag_changes.eclipse_flag.start_times[0] eq -1 and $
			   flag_changes.eclipse_flag.end_times[0] eq -1 ) do begin
			wide_time += [-1.,1.]*20*60.
			obs_obj-> set, obs_time_interval= anytim( wide_time )
			flag_changes = obs_obj -> changes()
		endwhile
		; Identify the closest transition.  If it's after the flare, use this as the start of 
		; a 4-min background interval.  If it's before the flare then use it as the end of a 
		; 4-min background interval.
		trans = flag_changes.eclipse_flag.start_times[where(flag_changes.eclipse_flag.state eq 1)]
		trans = [[trans],[flag_changes.eclipse_flag.end_times[where(flag_changes.eclipse_flag.state eq 1)]]]
		trans = transpose( trans )
		i = closest( trans, average(anytim( time_range )) )
		; Only one of the following conditions is true.
		if trans[i] lt anytim( time_range[0] ) then bkg_time_range = [-240.,0.]+trans[i]
		if trans[i] gt anytim( time_range[0] ) then bkg_time_range = [0., 240.]+trans[i]
		if trans[i] ge anytim( time_range[0] ) and trans[i] le anytim( time_range[1] ) then begin
			; This can't happen, but is included for completeness.
			print, 'Error finding background times.'
			return
		endif
	endif
	
	; The time range for SPEX needs to be extended to include this background interval.
	time_range_ext = anytim( time_range )		; extended time range
	; Only one of the following conditions is true.
;;;	if trans[i] lt anytim( time_range[0] ) then time_range_ext[0] = -240.+trans[i]
;;;	if trans[i] gt anytim( time_range[0] ) then time_range_ext[1] =  240.+trans[i]
	if anytim(bkg_time_range[1]) lt anytim( time_range[0] ) then $
		time_range_ext[0] = -240.+anytim(bkg_time_range[0]) else $
		if anytim(bkg_time_range[0]) gt anytim( time_range[1] ) then $
			time_range_ext[1] =  240.+anytim(bkg_time_range[1]) else begin
				print, 'Cannot use background during flare time interval.'
				return
			endelse

	; Prepare the time interval and background time interval stems for (all) filenames.
	tim = anytim( time_range, /yo )
	tim = strmid( tim,10,2 )+strmid( tim,13,2 )+strmid( tim,16,2 )
	bkg = anytim( bkg_time_range, /yo )
	bkg = strmid( bkg,10,2 )+strmid( bkg,13,2 )+strmid( bkg,16,2 )
	stem = '_'+tim[0]+'_'+tim[1]+'_bkg_'+bkg[0]+'_'+bkg[1]
	
	; Overplot background times on the observing summary.
	obs_obj_wide-> set, obs_time_interval= anytim( time_range )+[-1.,1.]*30.*60.
	hsi_linecolors
	obs_obj_wide-> plot, dim1_colors=[1,2,3,4,5,6,7,8,9]
	outplot, anytim([time_range[0],time_range[0]],/yo),[1,1.e6]
	outplot, anytim([time_range[1],time_range[1]],/yo),[1,1.e6]
	outplot, anytim([bkg_time_range[0],bkg_time_range[0]],/yo),[1,1.e6]
	outplot, anytim([bkg_time_range[1],bkg_time_range[1]],/yo),[1,1.e6]
	!p.multi=0

	; Also save the plot.
	write_png, dir_png+'/'+'time_interval_'+strtrim(flare_num,2)+stem+'.png', tvrd(/true)

	; Next is the creation of the count and response files using the SPEX object.
	; No pileup correction is used; this probably won't be necessary for these flares.
	obj = hsi_spectrum()
	obj-> set, obs_time_interval= time_range_ext
	obj-> set, decimation_correct= 1                                                             
	obj-> set, rear_decimation_correct= 0                                                        
	obj-> set, pileup_correct= 0                                                                 
	obj-> set, seg_index_mask= det_mask
	obj-> set, sp_chan_binning= 0
	obj-> set, sp_chan_max= 0
	obj-> set, sp_chan_min= 0
	obj-> set, sp_data_unit= 'Flux'
	obj-> set, sp_energy_binning= 14L
	; Binning code 14 is: 1-keV bins from 3 to 40 keV, 3-keV bins up to 100 keV,  
	; 5-keV bins up to 150 keV, 10 keV bins to 250 keV  (77 bins total)
	obj-> set, sp_semi_calibrated= 0B
	obj-> set, sp_time_interval= 4
	obj-> set, sum_flag= 1
	obj-> set, time_range= [0.0000000D, 0.0000000D]
	obj-> set, use_flare_xyoffset= 1

	if keyword_set( STOP ) then stop
	
	data = obj->getdata()    ; retrieve the spectrum data
	
	specfile = dir_fits+'/'+'hsi_spec_'+strtrim(flare_num,2)+stem+'.fits'
	srmfile  = dir_fits+'/'+'hsi_srm_' +strtrim(flare_num,2)+stem+'.fits'
	obj->filewrite, /buildsrm, all_simplify = 0, srmfile = srmfile, specfile = specfile

	obj_destroy, OBJ
	obj_destroy, obs_obj_wide
	obj_destroy, obs_obj

END
