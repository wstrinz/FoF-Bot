module FoFBot
	require 'json'
	module Messages

		def clid
			FoFBot::config.client_id
		end

		def roomID
			FoFBot::config.room_name
		end

		def farmerName
			FoFBot::config.name
		end

		def base
			{
				clientID: clid(),
				deviseName: "#{farmerName()}@#{farmerName()}.com",
				roomID: roomID()
			}
		end

		def joinRoom(roomName, farmerName, password="")
			# "event":"joinRoom","roomName":"test","password":"","userName":"a","clientID":"4","roomID":"test","deviseName":"wstrinz@gmail.com"
			msg = {
				event: "joinRoom",
				roomName: roomName,
				password: password,
				userName: farmerName,
				clientID: clid(),
				roomID: roomName,
        deviseName: "#{farmerName}@#{farmerName}.com"
      }
      msg.to_json
    end

    def getState(roomName, farmerName)
      # "event":"loadFromServer", "roomName":"test", "clientID":"18", "roomID":"test", "deviseName":"guest@guest.com"
      # "event":"getFarmerHistory", "clientID":"18", "roomID":"test", "deviseName":"guest@guest.com"
      # "event":"getFarmHistory", "clientID":"18", "roomID":"test", "deviseName":"guest@guest.com"

      msg = {
        event: 'loadFromServer',
        roomName: roomName,
        clientID: clid(),
        roomID: roomName,
        deviseName: "#{farmerName}@#{farmerName}.com"
      }
      
      msg.to_json
    end

		def plantField(field, crop)
			# "event":"plantField","field":1,"crop":"corn","clientID":"14","roomID":"test","deviseName":"wstrinz@gmail.com"
			msg = base.merge ({
				event: "plantField",
				field: field,
				crop: crop,
			})
			msg.to_json
		end

		def ready()
			# "event":"farmerReady","clientID":"14","roomID":"test","deviseName":"wstrinz@gmail.com"
			msg = base.merge ({
				event: "farmerReady",
			})
			msg.to_json
		end
	end

	class Message
		include Messages
	end
end