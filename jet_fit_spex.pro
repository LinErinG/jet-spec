;+
; Project     : Sophie/Lindsay jet project
;
; Name        : JET_FIT_SPEX
;
; Purpose     : Fit RHESSI spectrum for a jet event of interest.
;				This routine is meant to be used in partnership with JET_MAKE_SPEX.
;				Keywords should be matched between these two routines.
;				The routine fits a VTH + BPOW model.
;
; Syntax      : jet_fit_spex, flare_num
;
; Inputs      : FLARE_NUM = RHESSI flare list identifier for this flare
;
; Outputs     : NONE, but a fit results file and a plot of the fit count spectrum are 
;				written with auto-naming.  Auto-naming is 'ospex_results_12063050.fits' 
;				and 'fit_count_spectrum_12063050.png,' respectively.
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
;				STOP = 		Stop code at the indicated line.  For debugging.
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

PRO	jet_fit_spex, flare_num, delta_t=delta_t, time_range=time_range, $
				  bkg_time_range = bkg_time_range, $
				  stop = stop

	default, delta_t, 30.
	; Default time range will be 30 seconds around the flare peak.

	; Retrieve the flare record and choose the time if one is not given.
	if not keyword_set( time_range ) then begin
		; Get a year range in which to look for the flare record.
		year = '200'+strmid(strtrim(flare_num,2),0,1)
		if year eq '2001' then year = '20'+strmid(strtrim(flare_num,2),0,2)
		time_year = year+['-jan-01','-dec-31']
		; Pull the flare list for that whole year.  (This could be made more efficient.)
		flare_list_obj =  hsi_flare_list(obs_time_interval =  anytim(time_year, /ecs))
		flare_list =  flare_list_obj -> getdata()
		; Find our flare and set the time range to DELTA_T around peak.
		flare = flare_list( where(flare_list.id_number eq flare_num) )
		time_range = flare.peak_time + [-0.5,0.5]*delta_t
		; Check to make sure we're not exceeding the flare times!
		if time_range[0] lt flare.start_time then time_range[0] = flare.start_time
		if time_range[1] gt flare.end_time then time_range[1] = flare.end_time
	endif

	; Get the observing summary for a large interval for context.
	; Plot this again so we can make sure the intervals are still correct!
	; No need to save the plots again, though.
	obs_obj_wide = hsi_obs_summary()
	obs_obj_wide-> set, obs_time_interval= anytim( time_range )+[-1.,1.]*5.*60
	window, 1, xsi=600, ysi=600
	hsi_linecolors
	!p.multi=[0,1,2]
	obs_obj_wide-> plot, /ylog
	outplot, anytim([time_range[0],time_range[0]],/yo),[1,1.e6]
	outplot, anytim([time_range[1],time_range[1]],/yo),[1,1.e6]

	; Get the observing summary for our actual time of interest to extract attenuator state.
	obs_obj = hsi_obs_summary()
	obs_obj-> set, obs_time_interval= anytim( time_range )
	; Get the attenuator state (there are no changes, since we disallowed that in jet_make_spex).
	flag_changes = obs_obj -> changes()
	atten_state = flag_changes.attenuator_state[0].state
	
	; If no background time interval is specified, then find the nearest eclipse time.
	; THIS CODE SHOULD MIMIC EXACTLY WHAT IS IN JET_MAKE_SPEX!
	; Perhaps there is a better way to pass the variables rather than recalculating?

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
	if trans[i] lt anytim( time_range[0] ) then bkg_time_range = [-240.,0.]+trans[i]
	if trans[i] gt anytim( time_range[0] ) then bkg_time_range = [0., 240.]+trans[i]
	
	; Overplot background times on the observing summary.
	obs_obj-> plot
	outplot, anytim([time_range[0],time_range[0]],/yo),[1,1.e6]
	outplot, anytim([time_range[1],time_range[1]],/yo),[1,1.e6]
	outplot, anytim([bkg_time_range[0],bkg_time_range[0]],/yo),[1,1.e6]
	outplot, anytim([bkg_time_range[1],bkg_time_range[1]],/yo),[1,1.e6]
	!p.multi=0

	; Construct spec and srm filenames.
	specfile = 'hsi_spec_'+strtrim(flare_num,2)+'.fits'
	srmfile  = 'hsi_srm_' +strtrim(flare_num,2)+'.fits'
	
	; Give error if SPEC and SRM files are not found.
	if (exist(specfile) and exist(srmfile)) eq 0 then begin
		print, 'Error! SPEC or SRM file is missing.'
		return
	endif

	obj = ospex()
	obj-> set, spex_specfile= specfile
	obj-> set, spex_drmfile= srmfile
	obj-> set, fit_function= 'vth+bpow'
	obj-> set,spex_bk_time_interval= bkg_time_range
	obj-> set, spex_fit_time_interval = time_range

	obj-> set, fit_function= 'vth+bpow'
	obj-> set, fit_comp_params= [0.1, 1.0, 1.0, 0.000001, 1.70000, 20.0, 5.0]
	obj-> set, fit_comp_minima= [1.0e-20, 0.5, 0.01, 1.0e-10, 1.70, 10.00, 1.7]
	obj-> set, fit_comp_maxima= [1.0e+20, 8.0, 10.0, 1.0e+10, 10.0, 40.0, 10.0000]
	obj-> set, fit_comp_free_mask= [1B, 1B, 0B, 1B, 0B, 1B, 1B]
	obj-> set, fit_comp_spectrum= ['full', '']
	obj-> set, fit_comp_model= ['chianti', '']
	obj-> set, spex_autoplot_units= 'Flux'
	obj-> set, spex_fitcomp_plot_bk= 1
	obj-> set, spex_fit_manual=0

	; Energy range determination.  Lower edge determined by attenuator state.
	obj-> set, spex_erange = [4.,50.]
	if atten_state eq 1 then obj-> set, spex_erange = [6.,50.]
	if atten_state eq 3 then obj-> set, spex_erange = [10.,50.]
	; Automatically restrict upper energy range for fitting based on a statistical limit
	obj-> set, spex_fit_auto_erange = 1L
	obj-> set, spex_fit_auto_emax_thresh = 10.0		; 10.0 cts/bin is the default threshold.
	; See https://hesperia.gsfc.nasa.gov/ssw/packages/spex/doc/spex_fit_auto_erange_doc.htm for info.

	obj -> dofit, /all

	; Save a plot of the fit spectrum.
	obj -> plot_spectrum, /no_plotman, /show_fit, /bksub, /overlay_back
	write_png, 'fit_count_spectrum_'+strtrim(flare_num,2)+'.png', tvrd(/true)
	
	obj -> savefit, outfile='ospex_results_'+strtrim(flare_num,2)+'.fits'
	; THIS WILL OVERWRITE!

	if keyword_set( STOP ) then stop

END