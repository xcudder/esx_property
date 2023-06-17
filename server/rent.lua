function RunBilling()
	print('[^2INFO^7] ^5Property Rent Payments^7 Initiated')
	local continue = false -- why wouldnt a language implement continue goddamn...

	local current_time, diff = false, false
	local success = false
	local result = MySQL.query.await("SELECT CURRENT_TIMESTAMP AS time")
	current_time = result[1].time

	local PropertiesList = LoadResourceFile(GetCurrentResourceName(), 'properties.json')

	if PropertiesList then
		local Properties = json.decode(PropertiesList)
		Wait(1000)
		for i = 1, #Properties do
			local continue = false

			-- Not rented, skip
			if not Properties[i].Rented then
				print('[^2INFO^7] ^5Property not rented:^7 ' .. Properties[i].Name)
				continue = true
			end

			if not continue then
				print('[^2INFO^7] ^5Rented Property under analysis:^7 ' .. Properties[i].Name)

				-- Payed recently enough, skip
				if Properties[i].RentLastPayedIn and (current_time - Properties[i].RentLastPayedIn) < (Config.RentInterval * 1000) then
					print('[^2INFO^7] ^5Rented Property payment up to date:^7 ' .. Properties[i].Name)
					continue = true
				end
			end

			if not continue then
				print('[^2INFO^7] ^5Running billing for:^7 ' .. Properties[i].Name .. ', Renter: ' .. Properties[i].RentedFor)

				local xRenter = ESX.GetPlayerFromIdentifier(Properties[i].RentedFor)
				if xRenter then xRenter.showNotification("About to bill you", "error") end

				if BillRenter(Properties[i], current_time) then --succesfully payed
					Properties[i].RentLastPayedIn = current_time
				else -- no payment
			 		evictRenter(0, false, i, Properties)
			 	end
			 end
		end

		SaveResourceFile(GetCurrentResourceName(), 'properties.json', json.encode(Properties))
	else
		Properties = {}
		print("[^1ERROR^7]: ^5Properties.json^7 Not Found!")
	end
end

function BillRenter(property, current_time)
	local rent_price 		= ESX.Math.Round(property.Price / Config.RentDivider)
	local current_renter 	= ESX.GetPlayerFromIdentifier(property.RentedFor)

	if not current_renter then -- try to bill via database
		users = MySQL.query.await('SELECT * FROM users WHERE identifier = ?', {property.RentedFor})
		local accounts = json.decode(users[1].accounts)
		if accounts.bank >= rent_price then
			accounts.bank = accounts.bank - rent_price
			MySQL.update.await('UPDATE users SET accounts = ? WHERE identifier = ?', {json.encode(accounts), property.RentedFor})
			return true
		else
			return false
		end
	else -- player online, just bill it ingame
		if current_renter.getAccount("bank").money >= rent_price then
			current_renter.removeAccountMoney("bank", rent_price, "Rent")
			return true
		else
			return false
		end
	end
end

function evictRenter(source, cb, PropertyId, Properties)
  local xPlayer, evicter = false, false

  if source > 0 then
    xPlayer = ESX.GetPlayerFromId(source)
    evicter = xPlayer.getName()
  else
    evicter = "AutomatedBilling"
  end

  if source == 0 or IsPlayerAdmin(source, "EvictRenter") then
    local xRenter = ESX.GetPlayerFromIdentifier(Properties[PropertyId].RentedFor)
    if xRenter then
      xRenter.showNotification("Your Have Been ~r~Evicted~s~.", "error")
    end

    Properties[PropertyId].Keys[xRenter.identifier] = nil
    Properties[PropertyId].RentedFor = ""
    Properties[PropertyId].RentedForName = ""
    Properties[PropertyId].Rented = false

    TriggerClientEvent("esx_property:syncProperties", -1, Properties)
	SaveResourceFile(GetCurrentResourceName(), 'properties.json', json.encode(Properties))

    if Config.OxInventory then
      exports.ox_inventory:ClearInventory("property-" .. PropertyId)
    end
  end
  if cb then cb(IsPlayerAdmin(source, "EvictRenter")) end
end

RegisterCommand("run_property_billing", function(source, args)
  RunBilling()
end, false)