local TrackUtil = {}



function TrackUtil.db_to_lin(db)
    return 10^(db / 20)
end

function TrackUtil.lin_to_db(lin)
    if lin <= 0 then return -math.huge end
    return 20 * math.log(lin, 10)
end


function TrackUtil.find_track_by_name(project, name)
    local track_count = reaper.CountTracks(project)
    for i = 0, track_count - 1 do
        local tr = reaper.GetTrack(project, i)
        local _, tr_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        if tr_name == name then return tr, i end
    end
    return nil
end






return TrackUtil