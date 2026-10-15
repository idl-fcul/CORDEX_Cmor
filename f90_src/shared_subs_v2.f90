module shared_subs
    use datvar_s
    implicit none

contains

subroutine init_cordex_environment
    implicit none
    logical, save :: is_initialized = .false.

    ! Ensure the files are only read once per program run execution
    if (.not. is_initialized) then
        call read_cordex_config('inputlist.inp')
        call read_global_metadata('global_data.inp')
        is_initialized = .true.
    end if
end subroutine init_cordex_environment


subroutine read_cordex_config(cfg_filename)
    character(len=*), intent(in) :: cfg_filename
    integer :: unit_id, status_id

    open(newunit=unit_id, file=trim(cfg_filename), status='old', action='read', iostat=status_id)
    if (status_id /= 0) then
        print *, "ERROR: Could not open cordex run config file: ", trim(cfg_filename)
        stop 91
    end if

    ! Initialize both to the target missing_value flag before testing namelist file content
    height(1) = missing_value
    pres      = missing_value

    read(unit_id, nml=cordex_config, iostat=status_id)
    if (status_id /= 0) then
        print *, "ERROR: Failed to parse namelist &cordex_config from: ", trim(cfg_filename)
        close(unit_id)
        stop 92
    end if

    close(unit_id)
    print *, "Successfully loaded run configurations from: ", trim(cfg_filename)

    ! Automatically populate secondary targets if variables existed in the namelist file
    if (height(1) /= missing_value) then
        heightl = height(1)
        write(*,*) heightl
    end if

    if (pres /= missing_value) then
        presl       = pres
        pressure(1) = pres/100.
    end if

    wrfile = trim(adjustl(wrffile))

    ! Clean up character variables for NetCDF use
    varname       = trim(adjustl(vaid))
    vunits        = trim(adjustl(vunts))
    longname      = trim(adjustl(lname))
    standardname  = trim(adjustl(stname))
    cellmethods   = trim(adjustl(cmethods))

    write(ayearini,'(i4)')iniyear
    tunts='hours since '//ayearini//'-01-01 00:00'
    timeunits=trim(adjustl(tunts))                    

end subroutine read_cordex_config


subroutine read_global_metadata(meta_filename)
    character(len=*), intent(in) :: meta_filename
    integer :: unit_id, status_id

    open(newunit=unit_id, file=trim(meta_filename), status='old', action='read', iostat=status_id)
    if (status_id /= 0) then
        print *, "ERROR: Could not open global compliance metadata file: ", trim(meta_filename)
        stop 93
    end if

    read(unit_id, nml=global_metadata, iostat=status_id)
    if (status_id /= 0) then
        print *, "ERROR: Failed to parse namelist &global_metadata from: ", trim(meta_filename)
        close(unit_id)
        stop 94
    end if

    close(unit_id)

    print *, "Successfully loaded global metadata compliance paths from: ", trim(meta_filename)
end subroutine read_global_metadata
!
!-----------------------------------------------------------------------
!
subroutine read_geog
use netcdf
use datvar_s
integer :: j
!
! Read geog file
gfile = trim(dir)//trim(geog)//'.nc'
geofile = gfile(1:len_trim(gfile))

status = nf90_open(geofile, nf90_nowrite, ncid)
call ncerror(status, 'opening ' // trim(geofile))
!
! Get rotated coordinates
allocate(tlon(nlon, nlat), tlat(nlon, nlat))
allocate(rlon(nlon), rlat(nlat))

status=nf90_inq_varid(ncid,'CLONG',varid)
status=nf90_get_var(ncid,varid,tlon,(/xoffset,yoffset/),(/nlon,nlat/),(/1,1/))
call ncerror(status,'reading '//'CLONG')
!
status=nf90_inq_varid(ncid,'CLAT',varid)
status=nf90_get_var(ncid,varid,tlat,(/xoffset,yoffset/),(/nlon,nlat/),(/1,1/))
call ncerror(status,'reading '//'CLAT')
!
do i=1,nlon
 rlon(i)=tlon(i,1)
enddo
do j=1,nlat
 rlat(j)=tlat(1,j)
enddo
deallocate(tlon, tlat)
!
! Get geographical coordinates
!
allocate(lon(nlon,nlat), lat(nlon,nlat), landmask(nlon,nlat))

status = nf90_inq_varid(ncid, 'XLONG_M', varid)
status = nf90_get_var(ncid, varid, lon, (/xoffset, yoffset/), (/nlon, nlat/), (/1, 1/))

status = nf90_inq_varid(ncid, 'XLAT_M', varid)
status = nf90_get_var(ncid, varid, lat, (/xoffset, yoffset/), (/nlon, nlat/), (/1, 1/))
call ncerror(status,'reading '//'XLAT_M')

status=nf90_inq_varid(ncid,'LANDMASK',varid)
call ncerror(status,'getting var id')

status=nf90_get_var(ncid,varid,landmask,(/xoffset,yoffset/),(/nlon,nlat/),(/1,1/))
call ncerror(status,'reading '//'LANDMASK')

status = nf90_close(ncid)
call ncerror(status,'closing file')

end subroutine read_geog
!
!-----------------------------------------------------------------------
!
subroutine ncerror(status,info)
use netcdf
integer :: status
character(len=*),optional :: info

if( status /= 0 ) then
  print *, trim(nf90_strerror(status))
  if( present(info) ) print*,trim(info)
  stop 99
endif

end subroutine ncerror
!
!-----------------------------------------------------------------------
!
subroutine write_netcdf_2D(uvar)
use netcdf
use datvar_s
!
integer :: LatDimID,LonDimID,rlonDimID,rlatDimID,HDimID,BDimID,HeDimID
integer :: LonVarID,LatVarID,TBVarID,TVarID,rlatVarId,rlonVarID,uVarID,HVarID,rpVarID
real, dimension(nlon,nlat) :: uvar
real, parameter :: FillValue=1.e+20

status = nf90_create(fnameout, IOR(IOR(nf90_noclobber, nf90_netcdf4), nf90_classic_model), ncid)
call handle_err(status)

status = nf90_def_dim(ncid, "rlon", nlon, LonDimID)
status = nf90_def_dim(ncid, "rlat", nlat, LatDimID)

status = nf90_def_var(ncid, "lon", nf90_double, &
                            (/ LonDimId, LatDimID /), LonVarId)
status = nf90_def_var(ncid, "lat", nf90_double, &
                            (/ LonDimId, LatDimID /), LatVarId)
status = nf90_def_var(ncid, "rlon", nf90_double, &
                            (/ LonDimId /), rlonVarId)
status = nf90_def_var(ncid, "rlat", nf90_double, &
                            (/ LatDimID /), rlatVarId)
status = nf90_def_var(ncid, "rotated_latitude_longitude", nf90_char,rpVarId)

status = nf90_def_var(ncid, varname, nf90_float, &
                            (/ LonDimId, LatDimID /), uVarId)
call handle_err(status)

! chunk by [nlon, nlat, 1] to optimize for one time-step at a time
status = nf90_def_var_chunking(ncid, uVarId, nf90_chunked, (/ nlon, nlat, 1 /))
call handle_err(status)

! Compression call
status = nf90_def_var_deflate(ncid, uVarId, shuffle = 1, deflate = 1, deflate_level = 1)
call handle_err(status)                 

status = nf90_put_att(ncid, uVarID, "standard_name",standardname)
status = nf90_put_att(ncid, uVarID, "long_name",longname)
status = nf90_put_att(ncid, uVarID, "units",vunits)
status = nf90_put_att(ncid, uVarID, "grid_mapping","rotated_latitude_longitude")
status = nf90_put_att(ncid, uVarID, "coordinates","lat lon")
status = nf90_put_att(ncid, uVarID, "cell_methods",cellmethods)
status = nf90_put_att(ncid, uVarID, "cell_measures","area: areacella")
status = nf90_put_att(ncid, uVarID, "_FillValue",huge_val)
status = nf90_put_att(ncid, uVarID, "missing_value",huge_val)

status = nf90_put_att(ncid, LonVarID, "long_name","longitude")
status = nf90_put_att(ncid, LonVarID, "standard_name","longitude")
status = nf90_put_att(ncid, LonVarID, "units","degrees_east")
status = nf90_put_att(ncid, LonVarID, "_CoordinateAxisType","Lon")
call handle_err(status)

status = nf90_put_att(ncid, LatVarID, "long_name","latitude")
status = nf90_put_att(ncid, LatVarID, "standard_name","latitude")
status = nf90_put_att(ncid, LatVarID, "units","degrees_north")
status = nf90_put_att(ncid, LatVarID, "_CoordinateAxisType","Lat")
call handle_err(status)

status = nf90_put_att(ncid, rlonVarID, "long_name","longitude in rotated pole grid")
status = nf90_put_att(ncid, rlonVarID, "standard_name","grid_longitude")
status = nf90_put_att(ncid, rlonVarID, "units","degrees")
status = nf90_put_att(ncid, rlonVarID, "axis","X")
call handle_err(status)

status = nf90_put_att(ncid, rlatVarID, "long_name","latitude in rotated pole grid")
status = nf90_put_att(ncid, rlatVarID, "standard_name","grid_latitude")
status = nf90_put_att(ncid, rlatVarID, "units","degrees")
status = nf90_put_att(ncid, rlatVarID, "axis","Y")
call handle_err(status)

status = nf90_put_att(ncid, rpVarID, "grid_mapping_name","rotated_latitude_longitude")
status = nf90_put_att(ncid, rpVarID, "grid_north_pole_latitude", 39.25 )
status = nf90_put_att(ncid, rpVarID, "grid_north_pole_longitude", -162. )
status = nf90_put_att(ncid, rpVarID, "earth_radius", earth_radius )
call handle_err(status)

call write_global_attributes

status = nf90_enddef(ncid)

status = nf90_put_var(ncid, LonVarId, lon )
call handle_err(status)
status = nf90_put_var(ncid, LatVarId, lat )
call handle_err(status)
status = nf90_put_var(ncid, rlonVarId, rlon )
call handle_err(status)
status = nf90_put_var(ncid, rlatVarId, rlat )
call handle_err(status)
status = nf90_put_var(ncid, uVarId, uvar )
call handle_err(status)

status = nf90_close(ncid)
call handle_err(status)
!
return
end subroutine write_netcdf_2D
!
!-----------------------------------------------------------------------
!
subroutine write_netcdf_rtime_3d(uvar,mtime,utime,btime)
use netcdf
use datvar_s
!
integer :: LatDimID,LonDimID,BDimID,HDimID
integer :: LonVarID,LatVarID,TBVarID,TVarID,rlatVarId,rlonVarID,uVarID,rpVarID
integer :: HVarID
integer :: mtime
integer, dimension(2,mtime) :: btime
real, dimension(mtime) :: utime
real, dimension(nlon,nlat,mtime) :: uvar
character(len=40) :: day_units
real(kind=8) :: tfac

! Time axis in days since <iniyear>-01-01T00:00:00Z: values that the
! programs count in hours are divided by 24 (tfac), daily ones are kept.
day_units = 'days since '//ayearini//'-01-01T00:00:00Z'
tfac = 1.d0
if (timeunits(1:5) == 'hours') tfac = 24.d0

status = nf90_create(fnameout, IOR(IOR(nf90_clobber, nf90_netcdf4), nf90_classic_model), ncid)
call handle_err(status)

status = nf90_def_dim(ncid, "rlon", nlon, LonDimID)
status = nf90_def_dim(ncid, "rlat", nlat, LatDimID)
status = nf90_def_dim(ncid, "bnds", 2, BDimID)
status = nf90_def_dim(ncid, "time", nf90_unlimited, HDimID)

status = nf90_def_var(ncid, "time", nf90_double, (/ HDimID /), TVarId)
status = nf90_def_var(ncid, "time_bnds", nf90_double, (/ BDimID, HDimID /), TBVarId)

status = nf90_def_var(ncid, "lon", nf90_double, (/ LonDimId, LatDimID /), LonVarId)
status = nf90_def_var(ncid, "lat", nf90_double, (/ LonDimId, LatDimID /), LatVarId)
status = nf90_def_var(ncid, "rlon", nf90_double, (/ LonDimId /), rlonVarId)
status = nf90_def_var(ncid, "rlat", nf90_double, (/ LatDimID /), rlatVarId)
status = nf90_def_var(ncid, "rotated_latitude_longitude", nf90_char,rpVarId)

! Check for optional Z coordinate conditions
if (height(1) > 0.0) then
    status = nf90_def_var(ncid, "height", nf90_double, HVarId)
elseif (pressure(1) > 0.0) then
    status = nf90_def_var(ncid, "press", nf90_double, HVarId)
end if

status = nf90_def_var(ncid, varname, nf90_float, (/ LonDimId, LatDimID, HDimID /), uVarId)
call handle_err(status)

! chunk by [nlon, nlat, 1] to optimize for one time-step at a time
status = nf90_def_var_chunking(ncid, uVarId, nf90_chunked, (/ nlon, nlat, 1 /))
call handle_err(status)

! Compression call
status = nf90_def_var_deflate(ncid, uVarId, shuffle = 1, deflate = 1, deflate_level = 1)
call handle_err(status)

status = nf90_put_att(ncid, TVarID, "standard_name","time")
status = nf90_put_att(ncid, TVarID, "long_name","time")
status = nf90_put_att(ncid, TVarID, "bounds","time_bnds")
status = nf90_put_att(ncid, TVarID, "units",trim(day_units))
status = nf90_put_att(ncid, TVarID, "calendar","standard")
status = nf90_put_att(ncid, TVarID, "axis","T")

status = nf90_put_att(ncid, uVarID, "standard_name",standardname)
status = nf90_put_att(ncid, uVarID, "long_name",longname)
status = nf90_put_att(ncid, uVarID, "units",vunits)
status = nf90_put_att(ncid, uVarID, "grid_mapping","rotated_latitude_longitude")

! Dynamically update coordinates attribute string matching configuration state
if (height(1) > 0.0) then
    status = nf90_put_att(ncid, uVarID, "coordinates","lat lon time height")
elseif (pressure(1) > 0.0) then
    status = nf90_put_att(ncid, uVarID, "coordinates","lat lon time press")
else
    status = nf90_put_att(ncid, uVarID, "coordinates","lat lon time")
end if

status = nf90_put_att(ncid, uVarID, "cell_methods",cellmethods)
status = nf90_put_att(ncid, uVarID, "cell_measures","area: areacella")
status = nf90_put_att(ncid, uVarID, "_FillValue",huge_val)
status = nf90_put_att(ncid, uVarID, "missing_value",huge_val)

! Set attributes on the dynamic variable layer if it was initialized
if (height(1) > 0.0) then
    status = nf90_put_att(ncid, HVarID, "long_name","height above the surface")
    status = nf90_put_att(ncid, HVarID, "standard_name","height")
    status = nf90_put_att(ncid, HVarID, "positive","up")
    status = nf90_put_att(ncid, HVarID, "axis","Z")
    status = nf90_put_att(ncid, HVarID, "units","m")
elseif (pressure(1) > 0.0) then
    status = nf90_put_att(ncid, HVarID, "long_name","pressure")
    status = nf90_put_att(ncid, HVarID, "standard_name","air_pressure")
    status = nf90_put_att(ncid, HVarID, "positive","down")
    status = nf90_put_att(ncid, HVarID, "axis","Z")
    status = nf90_put_att(ncid, HVarID, "units","hPa")
end if

status = nf90_put_att(ncid, LonVarID, "long_name","longitude")
status = nf90_put_att(ncid, LonVarID, "standard_name","longitude")
status = nf90_put_att(ncid, LonVarID, "units","degrees_east")
status = nf90_put_att(ncid, LonVarID, "_CoordinateAxisType","Lon")
call handle_err(status)

status = nf90_put_att(ncid, LatVarID, "long_name","latitude")
status = nf90_put_att(ncid, LatVarID, "standard_name","latitude")
status = nf90_put_att(ncid, LatVarID, "units","degrees_north")
status = nf90_put_att(ncid, LatVarID, "_CoordinateAxisType","Lat")
call handle_err(status)

status = nf90_put_att(ncid, rlonVarID, "long_name","longitude in rotated pole grid")
status = nf90_put_att(ncid, rlonVarID, "standard_name","grid_longitude")
status = nf90_put_att(ncid, rlonVarID, "units","degrees")
status = nf90_put_att(ncid, rlonVarID, "axis","X")
call handle_err(status)

status = nf90_put_att(ncid, rlatVarID, "long_name","latitude in rotated pole grid")
status = nf90_put_att(ncid, rlatVarID, "standard_name","grid_latitude")
status = nf90_put_att(ncid, rlatVarID, "units","degrees")
status = nf90_put_att(ncid, rlatVarID, "axis","Y")
call handle_err(status)

status = nf90_put_att(ncid, rpVarID, "grid_mapping_name","rotated_latitude_longitude")
status = nf90_put_att(ncid, rpVarID, "grid_north_pole_latitude", 39.25 )
status = nf90_put_att(ncid, rpVarID, "grid_north_pole_longitude", -162. )
! Updated to map the new shared module constant parameter directly
status = nf90_put_att(ncid, rpVarID, "earth_radius", earth_radius )
call handle_err(status)

call write_global_attributes

status = nf90_enddef(ncid)

status = nf90_put_var(ncid, TVarId, dble(utime)/tfac )
call handle_err(status)
status = nf90_put_var(ncid, TBVarID, dble(btime)/tfac )
call handle_err(status)
status = nf90_put_var(ncid, LonVarId, lon )
call handle_err(status)
status = nf90_put_var(ncid, LatVarId, lat )
call handle_err(status)
status = nf90_put_var(ncid, rlonVarId, rlon )
call handle_err(status)
status = nf90_put_var(ncid, rlatVarId, rlat )
call handle_err(status)

! Write the values to the variable array if initialized
if (height(1) > 0.0) then
    status = nf90_put_var(ncid, HVarID, height )
    call handle_err(status)
elseif (pressure(1) > 0.0) then
    status = nf90_put_var(ncid, HVarID, pressure )
    call handle_err(status)
end if

status = nf90_put_var(ncid, uVarId, uvar )
call handle_err(status)

status = nf90_close(ncid)
call handle_err(status)

return
end subroutine write_netcdf_rtime_3d
!
!-----------------------------------------------------------------------
!
subroutine write_netcdf_rtime_soil(uvar,mtime,utime,btime)
use netcdf
use datvar_s
!
integer :: LatDimID,LonDimID,BDimID,HDimID,depth_dimid,SVarId,SBVarId
integer :: LonVarID,LatVarID,TBVarID,TVarID,rlatVarId,rlonVarID,uVarID,rpVarID
integer :: mtime
integer, dimension(2,mtime) :: btime
real, dimension(mtime) :: utime
real, dimension(nlon,nlat,nsoil,mtime) :: uvar
character(len=40) :: day_units
real(kind=8) :: tfac

! Time axis in days since <iniyear>-01-01T00:00:00Z: values that the
! programs count in hours are divided by 24 (tfac), daily ones are kept.
day_units = 'days since '//ayearini//'-01-01T00:00:00Z'
tfac = 1.d0
if (timeunits(1:5) == 'hours') tfac = 24.d0

status = nf90_create(fnameout, IOR(IOR(nf90_clobber, nf90_netcdf4), nf90_classic_model), ncid)
call handle_err(status)

status = nf90_def_dim(ncid, "rlon", nlon, LonDimID)
status = nf90_def_dim(ncid, "rlat", nlat, LatDimID)
status = nf90_def_dim(ncid, "nsoil", nsoil, depth_dimid)
status = nf90_def_dim(ncid, "bnds", 2, BDimID)
status = nf90_def_dim(ncid, "time", nf90_unlimited, HDimID)

status = nf90_def_var(ncid, "time", nf90_double, (/ HDimID /), TVarId)
status = nf90_def_var(ncid, "time_bnds", nf90_double, (/ BDimID, HDimID /), TBVarId)

status = nf90_def_var(ncid, "lon", nf90_double, (/ LonDimId, LatDimID /), LonVarId)
status = nf90_def_var(ncid, "lat", nf90_double, (/ LonDimId, LatDimID /), LatVarId)
status = nf90_def_var(ncid, "rlon", nf90_double, (/ LonDimId /), rlonVarId)
status = nf90_def_var(ncid, "rlat", nf90_double, (/ LatDimID /), rlatVarId)
status = nf90_def_var(ncid, "rotated_latitude_longitude", nf90_char,rpVarId)

status = nf90_def_var(ncid, "sdepth", nf90_double, (/ depth_dimid /), SVarId)
status = nf90_def_var(ncid, "sdepth_bnds", nf90_double, (/ BDimID, depth_dimid /), SBVarId)

status = nf90_def_var(ncid, varname, nf90_float, (/ LonDimId, LatDimID, depth_dimid, HDimID /), uVarId)
call handle_err(status)

! chunk by [nlon, nlat, 1] to optimize for one time-step at a time
status = nf90_def_var_chunking(ncid, uVarId, nf90_chunked, (/ nlon, nlat, nsoil, 1 /))
call handle_err(status)

! Compression call
status = nf90_def_var_deflate(ncid, uVarId, shuffle = 1, deflate = 1, deflate_level = 1)
call handle_err(status)

status = nf90_put_att(ncid, TVarID, "standard_name","time")
status = nf90_put_att(ncid, TVarID, "long_name","time")
status = nf90_put_att(ncid, TVarID, "bounds","time_bnds")
status = nf90_put_att(ncid, TVarID, "units",trim(day_units))
status = nf90_put_att(ncid, TVarID, "calendar","standard")
status = nf90_put_att(ncid, TVarID, "axis","T")

status = nf90_put_att(ncid, SVarId, "standard_name", "depth")
status = nf90_put_att(ncid, SVarId, "long_name", "Soil layer depth")
status = nf90_put_att(ncid, SVarId, "bounds", "sdepth_bnds")
status = nf90_put_att(ncid, SVarId, "units", "m")
status = nf90_put_att(ncid, SVarId, "positive", "down")
status = nf90_put_att(ncid, SVarId, "axis", "Z")


status = nf90_put_att(ncid, uVarID, "standard_name",standardname)
status = nf90_put_att(ncid, uVarID, "long_name",longname)
status = nf90_put_att(ncid, uVarID, "units",vunits)
status = nf90_put_att(ncid, uVarID, "grid_mapping","rotated_latitude_longitude")
status = nf90_put_att(ncid, uVarID, "coordinates","lat lon time")
status = nf90_put_att(ncid, uVarID, "cell_methods",cellmethods)
status = nf90_put_att(ncid, uVarID, "cell_measures","area: areacella")
status = nf90_put_att(ncid, uVarID, "_FillValue",huge_val)
status = nf90_put_att(ncid, uVarID, "missing_value",huge_val)

status = nf90_put_att(ncid, LonVarID, "long_name","longitude")
status = nf90_put_att(ncid, LonVarID, "standard_name","longitude")
status = nf90_put_att(ncid, LonVarID, "units","degrees_east")
status = nf90_put_att(ncid, LonVarID, "_CoordinateAxisType","Lon")
call handle_err(status)

status = nf90_put_att(ncid, LatVarID, "long_name","latitude")
status = nf90_put_att(ncid, LatVarID, "standard_name","latitude")
status = nf90_put_att(ncid, LatVarID, "units","degrees_north")
status = nf90_put_att(ncid, LatVarID, "_CoordinateAxisType","Lat")
call handle_err(status)

status = nf90_put_att(ncid, rlonVarID, "long_name","longitude in rotated pole grid")
status = nf90_put_att(ncid, rlonVarID, "standard_name","grid_longitude")
status = nf90_put_att(ncid, rlonVarID, "units","degrees")
status = nf90_put_att(ncid, rlonVarID, "axis","X")
call handle_err(status)

status = nf90_put_att(ncid, rlatVarID, "long_name","latitude in rotated pole grid")
status = nf90_put_att(ncid, rlatVarID, "standard_name","grid_latitude")
status = nf90_put_att(ncid, rlatVarID, "units","degrees")
status = nf90_put_att(ncid, rlatVarID, "axis","Y")
call handle_err(status)

status = nf90_put_att(ncid, rpVarID, "grid_mapping_name","rotated_latitude_longitude")
status = nf90_put_att(ncid, rpVarID, "grid_north_pole_latitude", 39.25 )
status = nf90_put_att(ncid, rpVarID, "grid_north_pole_longitude", -162. )
! Updated to map the new shared module constant parameter directly
status = nf90_put_att(ncid, rpVarID, "earth_radius", earth_radius )
call handle_err(status)

call write_global_attributes

status = nf90_enddef(ncid)

status = nf90_put_var(ncid, TVarId, dble(utime)/tfac )
call handle_err(status)
status = nf90_put_var(ncid, TBVarID, dble(btime)/tfac )
call handle_err(status)
status = nf90_put_var(ncid, LonVarId, lon )
call handle_err(status)
status = nf90_put_var(ncid, LatVarId, lat )
call handle_err(status)
status = nf90_put_var(ncid, rlonVarId, rlon )
call handle_err(status)
status = nf90_put_var(ncid, rlatVarId, rlat )
call handle_err(status)
! depth coordinate = middle of each soil layer (sdepth holds the layer thicknesses)
status = nf90_put_var(ncid, SVarID, anint(5.d5*(dble(sdepth_bounds(1,:))+dble(sdepth_bounds(2,:))))/1.d6 )
call handle_err(status)
status = nf90_put_var(ncid, SBVarID, anint(1.d6*dble(sdepth_bounds))/1.d6 )
call handle_err(status)
status = nf90_put_var(ncid, uVarId, uvar )
call handle_err(status)

status = nf90_close(ncid)
call handle_err(status)

return
end subroutine write_netcdf_rtime_soil
!
!
!
subroutine write_global_attributes
    use netcdf
    use datvar_s
!
    character(len=20)  :: utc_now
    character(len=49)  :: tracking
    character(len=400) :: history_str

    ! Dynamically trigger namelist reading cleanly right before writing attributes
    call init_cordex_environment

    ! Creation time (UTC, YYYY-MM-DDThh:mm:ssZ), tracking_id and history
    call utc_timestamp(utc_now)
    call new_tracking_id(tracking)
    history_str = trim(utc_now)//';rewrote data to be consistent with correct frequency '// &
                  trim(frequency)//' for variable '//trim(varname)//' found in table CORDEX-CMIP6_'// &
                  trim(frequency)//'.'

    ! String Attributes
    status = nf90_put_att(ncid, nf90_global, "Conventions", trim(conventions))
    status = nf90_put_att(ncid, nf90_global, "activity_id", trim(activity_id))
    status = nf90_put_att(ncid, nf90_global, "contact", trim(contact))
    status = nf90_put_att(ncid, nf90_global, "creation_date", trim(utc_now))
    status = nf90_put_att(ncid, nf90_global, "CORDEX_domain", trim(CORDEX_domain))
    status = nf90_put_att(ncid, nf90_global, "domain", trim(domain_name))
    status = nf90_put_att(ncid, nf90_global, "domain_id", trim(domain_id))
    status = nf90_put_att(ncid, nf90_global, "driving_experiment", trim(experiment))
    status = nf90_put_att(ncid, nf90_global, "driving_experiment_id", trim(experiment_id))
    status = nf90_put_att(ncid, nf90_global, "driving_institution_id", trim(driving_inst_id))
    status = nf90_put_att(ncid, nf90_global, "driving_source_id", trim(driving_source_id))
    status = nf90_put_att(ncid, nf90_global, "driving_source", trim(driving_source))
    status = nf90_put_att(ncid, nf90_global, "driving_variant_label", trim(driving_variant))
    status = nf90_put_att(ncid, nf90_global, "external_variables", "areacella")
    status = nf90_put_att(ncid, nf90_global, "frequency", trim(frequency))
    status = nf90_put_att(ncid, nf90_global, "further_info_url", trim(further_info_url))
    status = nf90_put_att(ncid, nf90_global, "grid", trim(grid_desc))
    status = nf90_put_att(ncid, nf90_global, "history", trim(history_str))
    status = nf90_put_att(ncid, nf90_global, "institution", trim(institution))
    status = nf90_put_att(ncid, nf90_global, "institution_id", trim(institution_id))
    status = nf90_put_att(ncid, nf90_global, "label", trim(label))
    status = nf90_put_att(ncid, nf90_global, "label_extended", trim(label_ext))
    status = nf90_put_att(ncid, nf90_global, "license", trim(license))
    status = nf90_put_att(ncid, nf90_global, "mip_era", trim(mip_era))
    status = nf90_put_att(ncid, nf90_global, "product", trim(product))
    status = nf90_put_att(ncid, nf90_global, "project_id", trim(project_id))
    status = nf90_put_att(ncid, nf90_global, "release_year", trim(release_year))
    status = nf90_put_att(ncid, nf90_global, "source", trim(source_desc))
    status = nf90_put_att(ncid, nf90_global, "source_id", trim(source_id))
    status = nf90_put_att(ncid, nf90_global, "source_type", trim(source_type))
    status = nf90_put_att(ncid, nf90_global, "tracking_id", trim(tracking))
    status = nf90_put_att(ncid, nf90_global, "variable_id", trim(varname))
    status = nf90_put_att(ncid, nf90_global, "version_realization", trim(version_real))
    status = nf90_put_att(ncid, nf90_global, "simulation_start_date", trim(sim_start_date))

    ! Numeric Attributes
    status = nf90_put_att(ncid, nf90_global, "west_east_grid_dimension", we_dim)
    status = nf90_put_att(ncid, nf90_global, "south_north_grid_dimension", sn_dim)
    status = nf90_put_att(ncid, nf90_global, "bottom_top_grid_dimension", bt_dim)
    status = nf90_put_att(ncid, nf90_global, "dx", dx_val)
    status = nf90_put_att(ncid, nf90_global, "dy", dy_val)

end subroutine write_global_attributes
!
!-------------------------------------------------------------------------------------
!
! File-name time range "<first>-<last>" from the first and last time values
! (in timeunits since <iniyear>-01-01): YYYYMMDDhhmm for sub-daily files,
! YYYYMMDD for daily and YYYYMM for monthly ones (CORDEX-CMIP6 file names).
!
function time_label(t1, t2) result(label)
    real, intent(in) :: t1, t2
    character(len=25) :: label
    label = trim(time_stamp(t1))//'-'//trim(time_stamp(t2))
end function time_label

function time_stamp(t) result(stamp)
    real, intent(in) :: t
    character(len=12) :: stamp
    integer(kind=8) :: mins
    integer :: iy, days, y, m, d
    real(kind=8) :: tfac

    tfac = 1.d0
    if (timeunits(1:5) == 'hours') tfac = 24.d0
    read(ayearini,*) iy
    mins = nint(dble(t)/tfac*1440.d0, kind=8)
    days = days_from_civil(iy, 1, 1) + int(floor(dble(mins)/1440.d0))
    mins = modulo(mins, 1440_8)
    call civil_from_days(days, y, m, d)
    select case (trim(frequency))
    case ('day')
        write(stamp,'(i4.4,2i2.2)') y, m, d
    case ('mon')
        write(stamp,'(i4.4,i2.2)') y, m
    case default
        write(stamp,'(i4.4,4i2.2)') y, m, d, int(mins/60), int(mod(mins,60_8))
    end select
end function time_stamp

! Days since 1970-01-01 of a (proleptic Gregorian) date, and back.
pure function days_from_civil(yy, m, d) result(days)
    integer, intent(in) :: yy, m, d
    integer :: days, y, era, yoe, doy, doe
    y = yy
    if (m <= 2) y = y - 1
    era = merge(y, y - 399, y >= 0) / 400
    yoe = y - era*400
    doy = (153*mod(m + 9, 12) + 2)/5 + d - 1
    doe = yoe*365 + yoe/4 - yoe/100 + doy
    days = era*146097 + doe - 719468
end function days_from_civil

pure subroutine civil_from_days(days_in, y, m, d)
    integer, intent(in)  :: days_in
    integer, intent(out) :: y, m, d
    integer :: days, era, doe, yoe, doy, mp
    days = days_in + 719468
    era = merge(days, days - 146096, days >= 0) / 146097
    doe = days - era*146097
    yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365
    y   = yoe + era*400
    doy = doe - (365*yoe + yoe/4 - yoe/100)
    mp  = (5*doy + 2)/153
    d   = doy - (153*mp + 2)/5 + 1
    m   = merge(mp + 3, mp - 9, mp < 10)
    if (m <= 2) y = y + 1
end subroutine civil_from_days
!
! Current time in UTC as YYYY-MM-DDThh:mm:ssZ (date_and_time gives local
! time plus its offset from UTC, which is removed here).
!
subroutine utc_timestamp(stamp)
    character(len=20), intent(out) :: stamp
    integer :: v(8), days, mins, y, m, d

    call date_and_time(values=v)
    ! local date and minutes of the day, minus the UTC offset v(4) (minutes)
    mins = v(5)*60 + v(6) - v(4)
    days = days_from_civil(v(1), v(2), v(3)) + floor(real(mins)/1440.)
    mins = modulo(mins, 1440)
    call civil_from_days(days, y, m, d)
    write(stamp,'(i4.4,"-",i2.2,"-",i2.2,"T",i2.2,":",i2.2,":",i2.2,"Z")') &
          y, m, d, mins/60, mod(mins,60), v(7)
end subroutine utc_timestamp
!
!-------------------------------------------------------------------------------------
!
! tracking_id = "hdl:21.14103/" + a new random UUID (version 4) for every file.
! Uses the Linux kernel's UUID generator; falls back to random_number.
!
subroutine new_tracking_id(tid)
    character(len=49), intent(out) :: tid
    character(len=36) :: uuid
    character(len=16), parameter :: hexd = '0123456789abcdef'
    logical, save :: seeded = .false.
    integer :: u, ios, i, k
    real :: r

    uuid = ''
    open(newunit=u, file='/proc/sys/kernel/random/uuid', status='old', action='read', iostat=ios)
    if (ios == 0) then
        read(u,'(a36)', iostat=ios) uuid
        close(u)
    end if
    if (ios /= 0 .or. len_trim(uuid) /= 36) then
        if (.not. seeded) then
            call random_seed()
            seeded = .true.
        end if
        do i = 1, 36
            select case (i)
            case (9, 14, 19, 24)
                uuid(i:i) = '-'
            case (15)
                uuid(i:i) = '4'                        ! version 4
            case default
                call random_number(r)
                k = int(r*16.)
                if (i == 20) k = 8 + mod(k, 4)         ! variant 10xx
                uuid(i:i) = hexd(k+1:k+1)
            end select
        end do
    end if
    tid = 'hdl:21.14103/'//uuid
end subroutine new_tracking_id
!
!-------------------------------------------------------------------------------------
!
subroutine handle_err(status)
use netcdf
integer, intent ( in) :: status

if(status /= nf90_noerr) then
  print*, trim(nf90_strerror(status))
  stop 98
end if
end subroutine handle_err
!
end module shared_subs
