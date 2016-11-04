module View exposing (view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed
import Http exposing (..)
import List exposing (..)
import InlineHover exposing (hover)
import Regex exposing (..)
import Animation
import Animation.Messenger
import String
import State exposing (..)
import Types exposing (..)
import User exposing (..)
import Address exposing (..)
import DataSetInfo exposing (..)


postcodeRegex : Regex
postcodeRegex =
    regex "(GIR 0AA)|((([A-Z]\\d+)|(([A-Z]{2}\\d+)|(([A-Z][0-9][A-HJKSTUW])|([A-Z]{2}[0-9][ABEHMNPRVWXY]))))\\s?[0-9][A-Z]{2})"


searchUrl : String -> String
searchUrl search =
    url "https://www.google.co.uk/search" [ ( "q", search ) ]


mapUrl : String -> String
mapUrl search =
    url "https://www.google.com/maps/embed/v1/place"
        [ ( "key", "AIzaSyAJTbvZlhyNCaRDef08HD-OYC_CTPwk2Vc" )
        , ( "q", search )
        ]



-- Lists of style properties


styleCandidate : List ( String, String )
styleCandidate =
    [ ( "display", "inline-block" )
    , ( "width", "30%" )
    , ( "margin", ".1em" )
    , ( "padding", "3px" )
    , ( "border", "1px solid black" )
    , ( "background-color", "#DDD" )
    , ( "height", "7em" )
    , ( "overflow-y", "scroll" )
    ]


styleCandidateHover : List ( String, String )
styleCandidateHover =
    [ ( "outline", "3px solid #F00" ) ]


styleEmbeddedMap : List ( String, String )
styleEmbeddedMap =
    [ ( "width", "98%" )
    , ( "height", "15em" )
    , ( "border", "0" )
    , ( "margin", "1em 0 0 0" )
    ]


-- HTML Generating Functions



viewEmbeddedMap : String -> Html Msg
viewEmbeddedMap search =
    iframe
        [ style styleEmbeddedMap
        , src (mapUrl (search ++ ", United Kingdom"))
        ]
        []


viewCandidate : ( Candidate, TestId ) -> Html Msg
viewCandidate candidateTestId =
    let
        candidate =
            fst candidateTestId

        testId =
            snd candidateTestId
    in
        hover
            styleCandidateHover
            li
                [ style styleCandidate
                , onClick
                      (SelectCandidate ( candidate.uprn, testId ))
                ]
                [ ul
                    []
                    [ li [] [ text candidate.name ]
                    , li [] [ text candidate.parentAddressName ]
                    , li [] [ text candidate.streetName ]
                    , li [] [ text candidate.streetTown ]
                    ]
                ]


viewPassButton : TestId -> Html Msg
viewPassButton testId =
    button
        [ class "button"
        , style
              [ ( "white-space", "nowrap" )
              , ( "line-height", ".6" )
              ]
        , onClick (SelectCandidate ( "_unknown_", testId ))
        ]
        [ text "Pass" ]



viewAddress : Animation.Messenger.State Msg -> Address -> Html Msg
viewAddress animState address =
    let
        addTestId : Candidate -> ( Candidate, TestId )
        addTestId ca =
            ( ca, address.test.id )

        testNameHtml =
            p [ style [ ( "font-weight", "bold" ) ] ] [ text address.test.name ]

        viewTestLine line =
            p [ style [ ( "margin", "0" ) ] ] [ text line ]

        testHtml =
            div
                [ class "test-address" ]
                [ div []
                    [ testNameHtml
                    , h2
                        [ style
                            [ --( "margin", "0 0 .5em 0" )
--                            , ( "border", "2px solid #BBB" )
--                            , ( "padding", "3px" )
                            ]
                        ]
                        (List.concat
                            [ (map
                                viewTestLine
                                (String.split "," address.test.address)
                              )
                            ]
                        )
                    , viewEmbeddedMap address.test.address
                    ]
                ]
    in
        div
            (Animation.render animState
                ++ [ style [ ( "position", "relative" ) ] ]
            )
            [ div
                [ class "grid-row" ]
                [ testHtml
                , Html.Keyed.node "div"
                    [ style
                          [ ( "float", "right" )
                          , ( "width", "70%" )
                          ]
                    ]
                    [ ( (toString address.test.id) ++ "h2", h2
                        [ class "heading-small" ]
                        [ text "Select the matching address below, or "
                        , viewPassButton address.test.id
                        ])
                    , ( (toString address.test.id) ++ "ul", ul
                        []
                        (map
                             viewCandidate
                             (map addTestId address.candidates)
                        ))

                    ]
                ]
            ]


viewAddresses : Animation.Messenger.State Msg -> Int -> List Address -> Html Msg
viewAddresses animState numberRemaining addresses =
    div []
        ((viewProgressBar numberRemaining 5)
            :: (map (viewAddress animState) addresses)
        )


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
    div
        [ style [ ( "margin-bottom", "20px" ) ] ]
        [ case users of
            NotAsked ->
                p [] [ text "Users not fetched " ]

            Loading ->
                p [] [ text "Loading users" ]

            Success userList ->
                let
                    message =
                        if currentUserId == 0 then
                            "Please tell me who you are: "
                        else
                            "Current user: "
                in
                    div []
                        [ text message
                        , viewUserSelect currentUserId userList
                        ]

            Failure error ->
                p []
                    [ text
                        ("Error loading user data: " ++ (error |> toString))
                    ]
        ]


viewProgressBar : Int -> Int -> Html Msg
viewProgressBar remaining max =
    let
        percent : Float
        percent =
            100 * (toFloat (max - remaining + 1)) / (toFloat max)
    in
        div
            [ style
                [ ( "height", "20px" )
                , ( "margin-bottom", "5px" )
                ]
            ]
            [ div
                [ style
                    [ ( "background-color", "#DDD" )
                    , ( "height", "20px" )
                    , ( "width", "100%" )
                    ]
                ]
                [ "-" |> text ]
            , div
                [ style
                    [ ( "position", "relative" )
                    , ( "top", "-20px" )
                    , ( "background-color", "orange" )
                    , ( "color", "white" )
                    , ( "font-weight", "bold" )
                    , ( "font-size", "1em" )
                    , ( "height", "20px" )
                    , ( "width", (percent |> toString) ++ "%" )
                    , ( "text-align", "center" )
                    ]
                ]
                [ (toString
                    (max + 1 - remaining)
                  )
                    ++ "/"
                    ++ (toString max)
                    |> text
                ]
            ]


viewAddressSection
    :  Animation.Messenger.State Msg
    -> UserId
    -> RemoteAddresses
    -> Html Msg
viewAddressSection animState currentUserId addresses =
    if currentUserId == 0 then
        p [] []
    else
        case addresses of
            Success listAddresses ->
                if listAddresses == [] then
                    div []
                        [ h2 [ class "heading-large" ] [ text "All done!" ]
                        , button
                            [ onClick FetchAddresses
                            , class "button"
                            ]
                            [ text "Give me more!" ]
                        , p [ style [ ( "padding-top", "1em" ) ] ]
                            [ a
                                [ href "/match/scores/" ]
                                [ text "See all scores" ]
                            ]
                        ]
                else
                    viewAddresses
                        animState
                        (length listAddresses)
                        (take 1 listAddresses)

            Loading ->
                p [] [ text "Loading test addresses" ]

            Failure err ->
                p [] [ text ("Failed loading addresses: " ++ (toString err)) ]

            NotAsked ->
                p [] [ text "Loading test addresses" ]


viewInfoSection : RemoteDataSetInfo -> Html Msg
viewInfoSection info =
    h1
        [ class "heading-small" ]
        [ case info of
            NotAsked ->
                text "Fetching"

            Loading ->
                text "Loading infos"

            Success infoDict ->
                DataSetInfo.get "title" infoDict
                    |> Maybe.withDefault "No title"
                    |> text

            Failure error ->
                text ("Error loading dataset title" ++ (error |> toString))
        ]


view : Model -> Html Msg
view model =
    div
        [ style [ ( "font-size", "90%" ) ] ]
        [ viewUsersSection model.currentUserId model.users
        , viewInfoSection model.dataSetInfo
        , viewAddressSection
            model.animationStyle
            model.currentUserId
            model.addresses
        ]
