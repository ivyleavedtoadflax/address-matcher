module View exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (..)
import List exposing (..)
import InlineHover exposing (hover)
import State exposing (..)
import Types exposing (..)
import User exposing (..)
import Address exposing (..)
import Regex exposing (..)


postcodeRegex : Regex
postcodeRegex =
    regex "(GIR 0AA)|((([A-Z]\\d+)|(([A-Z]{2}\\d+)|(([A-Z][0-9][A-HJKSTUW])|([A-Z]{2}[0-9][ABEHMNPRVWXY]))))\\s?[0-9][A-Z]{2})"


extractPostcode : String -> String
extractPostcode text =
    let
        match =
            find (AtMost 1) postcodeRegex text
                |> head
                |> Debug.log "match"
    in
        case match of
            Nothing ->
                text

            Just m ->
                m.match


searchUrl : String -> String
searchUrl search =
    url "https://www.google.co.uk/search"
        [ ( "q", search ) ]


mapUrl : String -> String
mapUrl search =
    url "https://www.google.com/maps/embed/v1/place"
        [ ( "key", "AIzaSyAJTbvZlhyNCaRDef08HD-OYC_CTPwk2Vc" ), ( "q", search ) ]


liStyle : Int -> List ( String, String )
liStyle index =
    let
        always =
            [ ( "border", "3px solid white" )
            , ( "margin-left", "1em" )
            , ( "padding-left", ".2em" )
            ]
    in
        if index % 2 == 0 then
            ( "background-color", "#eee" ) :: always
        else
            always


viewExternalLink : String -> String -> Html Msg
viewExternalLink linkText linkHref =
    a
        [ href linkHref
        , target "blank"
        , style [ ( "font-size", "80%" ) ]
        ]
        [ text linkText
        , sup [] [ text "⧉" ]
        ]


viewEmbeddedMap : String -> Html Msg
viewEmbeddedMap search =
    iframe
        [ width 300
        , height 400
        , class "column-one-third"
        , style
            [ ( "border", "0" )
            , ( "margin-bottom", "20px" )
            ]
        , src (mapUrl (search ++ ", United Kingdom"))
        ]
        []


viewCandidate : Int -> ( CandidateAddress, TestAddressId ) -> Html Msg
viewCandidate index candidate =
    let
        candidateAddress =
            fst candidate

        testId =
            snd candidate
    in
        hover
            [ ( "border", "3px solid red" )
            , ( "border-radius", "10px" )
            ]
            li
                [ style (liStyle index)
                , onClick (SelectCandidate ( candidateAddress.uprn, testId ))
                ]
                [ text ("🢂 " ++ candidateAddress.address)
                , text " "
                , small []
                    [ viewExternalLink " map" (mapUrl candidateAddress.address) ]
                ]


viewAddress : Address -> Html Msg
viewAddress address =
    let
        addTestId : CandidateAddress -> ( CandidateAddress, TestAddressId )
        addTestId ca =
            ( ca, address.test.id )

        notSureChoice =
            hover
                [ ( "border", "3px solid red" )
                , ( "border-radius", "10px" )
                ]
                li
                    [ style (liStyle -1)
                    , onClick (NoMatch address.test.id)
                    ]
                    [ span
                        [ style
                            [ ( "font-weight", "bold" ) ]
                        ]
                        [ text "🢂 Pass ¯\\_(ツ)_/¯" ]
                    ]

        testAddressHtml =
            h1
                [ class "heading-medium" ]
                [ text (address.test.address)
                , span [] [ text " - " ]
                , viewExternalLink "Search" (searchUrl address.test.address)
                ]
    in
        div
            []
            [ testAddressHtml
            , div
                [ class "grid-row" ]
                [ ul [ class "column-two-thirds" ]
                    (notSureChoice
                        :: (indexedMap viewCandidate (map addTestId address.candidates))
                    )
                , viewEmbeddedMap (extractPostcode address.test.address)
                ]
            ]


viewAddresses : List Address -> Html Msg
viewAddresses addresses =
    div [] (map viewAddress addresses)


viewUserOption : UserId -> User -> Html Msg
viewUserOption currentUserId user =
    option
        [ value (user |> User.id |> toString)
        , selected (currentUserId == User.id user)
        ]
        [ user |> User.name |> text ]


viewUserSelect : UserId -> List User -> Html Msg
viewUserSelect currentUserId users =
    select [ onInput UserChange ]
        ((option [] [ text "Select a user" ])
            :: (map (viewUserOption currentUserId) users)
        )


viewUsersSection : UserId -> RemoteUsers -> Html Msg
viewUsersSection currentUserId users =
    case users of
        NotAsked ->
            p [] [ text "Users not fetched " ]

        Loading ->
            p [] [ text "Loading users" ]

        Success userList ->
            let
                message =
                    if currentUserId == 0 then
                        "Please tell me who you are:"
                    else
                        "Current user:"
            in
                div []
                    [ p [] [ text message ]
                    , viewUserSelect currentUserId userList
                    ]

        Failure error ->
            p [] [ text ("Error loading user data: " ++ (error |> toString)) ]


view : Model -> Html Msg
view model =
    let
        addressSection : Html Msg
        addressSection =
            if model.currentUserId == 0 then
                p [] []
            else
                case model.addresses of
                    Success listAddresses ->
                        if listAddresses == [] then
                            p []
                                [ p
                                    [ style
                                        [ ( "font-size", "20px" ) ]
                                    ]
                                    [ text "Your score is 244" ]
                                , p
                                    [ style
                                        [ ( "font-size", "30px" )
                                        , ( "color", "gold" )
                                        ]
                                    ]
                                    [ text "🏆 You're in first place! 🏆" ]
                                , button
                                    [ onClick FetchAddresses
                                    , style
                                        [ ( "font-size", "50px" )
                                        , ( "font-weight", "bold" )
                                        , ( "margin-top", "20px" )
                                        ]
                                    ]
                                    [ text "Give me more!" ]
                                ]
                        else
                            viewAddresses (take 1 listAddresses)

                    Loading ->
                        p [] [ text "Loading addresses" ]

                    _ ->
                        p [] [ text "No addresses" ]
    in
        div
            [ style [ ( "font-size", "90%" ) ] ]
            [ viewUsersSection model.currentUserId model.users
            , addressSection
              -- , div [] [ text (toString model) ]
            ]
