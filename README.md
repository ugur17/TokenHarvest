Shareholders:
- Operation center
- Producer
- Inspector
- Customer
- Investor


*** Admin page (operation center) will make protocol with the producers
	* Firstly, operation center will be only 1 metamask account and dao will be maintenanced after i have done all the works 

Customer or Investor Pages:
1 - “Home” page will show us the certification nfts of products
    * This page will serve the purpose of good exchange
    * Items will be here to allow consumers to buy some of them
    * Any account (including inspector, producer, investor, consumer or any operation center member) will be able to buy goods with his/her tokens in this page
? - 2 - “Exchange” page will allow investors to buy tokens from market price
	* Will allow producers to convert their tokens into local currency when they sell their goods
    * Any account (including inspector, producer, investor, consumer or any operation center member) will be able to trade tokens with local currency


Producer Pages:
1 - “Products” page will show all of the infos about any producer's products
    * There will be 2 functionality:
        a - Show the list of products that are available in producer's stock
        b - Make request to any inspector to certificate producer's good
    * Producer will be able to see his/her product list in three different category
        a - Uncertified products
        b - Products awaiting inspectors
        c - Certified products
2 - “Producer Profile” page will show the infos about the producer including waiting or signed protocol with the operation center 
    * This page will show the informations about the farm itself and the signed or awaiting protocol between the producer and operation center
    * Will show the information about last inspection (last inspection date, who is the inspector etc.) and the upcoming inspection that the producer needs to request

Inspector Pages:
1 - “Inspections” page will show the requests which are coming from producers to inspectors
    * This page will show the certification requests from producers in 2 different category
        a - Farm certification requests
        b - Product certification requests
    * Will also show the accepted or declined certification requests in the same categories


Back-end Spesifications:
* - There will be only one erc-1155 nft collection named "Token Harvest" 
    a - When a farmer wants to mint new nft, the token id of nft will be the decimal convertion of ascii convertion of name/company name of the farmer (Name/company name will act as primary key)
    b - When farmer wants to mint more than one nft, id calculation will be like:
        id = decimal(ascii(name + counter))
    c - Farmer will be able to mint different amount of nft tokens which has the same id
        i - For instance, if farmer produce 1000 kg of tomato, then he/she will be able to produce 40 different nft token which each nft represents 25 kg.



Questions:
1 - When farmer make request to the inspector, which inspector will be assigned? How we will decide it?
2 - Should producers be allow to sell uncertified products?
3 - What is going to be the supply amount of token? Total supply? Initial supply? In which conditions, who will mint it?
4 - How much percentage the fee is going to be? How will the system receive the fee?
5 - How the token credit system works? Will be any difference between the token which credited by operation center and the token bought from exchange page? How will producer pay back the credited token?
6 - What will product attributes be to write as metadata of token?
